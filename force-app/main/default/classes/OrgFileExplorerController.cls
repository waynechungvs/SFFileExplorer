public without sharing class OrgFileExplorerController {
  public class FileWrapper {
    @AuraEnabled
    public Id contentVersionId { get; set; }
    @AuraEnabled
    public Id contentDocumentId { get; set; }
    @AuraEnabled
    public String fileName { get; set; }
    @AuraEnabled
    public String fileType { get; set; }
    @AuraEnabled
    public String fileSize { get; set; }
    @AuraEnabled
    public String createdBy { get; set; }
    @AuraEnabled
    public Id createdById { get; set; }
    @AuraEnabled
    public DateTime createdDate { get; set; }
    @AuraEnabled
    public String lastModifiedBy { get; set; }
    @AuraEnabled
    public Id lastModifiedById { get; set; }
    @AuraEnabled
    public DateTime lastModifiedDate { get; set; }
    @AuraEnabled
    public String currentOwner { get; set; }
    @AuraEnabled
    public Id currentOwnerId { get; set; }
    @AuraEnabled
    public Boolean isOwnerActive { get; set; }
    @AuraEnabled
    public Integer linkCount { get; set; }
    @AuraEnabled
    public String previewUrl { get; set; }
    @AuraEnabled
    public String downloadUrl { get; set; }
    @AuraEnabled
    public Boolean isOrphaned { get; set; }
    @AuraEnabled
    public String usageLevel { get; set; } // 'orphaned', 'low_usage', 'well_connected'
  }

  public class FileResult {
    @AuraEnabled
    public List<FileWrapper> files { get; set; }
    @AuraEnabled
    public Integer totalCount { get; set; }
    @AuraEnabled
    public Integer pageNumber { get; set; }
    @AuraEnabled
    public Integer pageSize { get; set; }
  }

  @AuraEnabled(cacheable=true)
  public static FileResult getOrgFiles(
    String searchTerm,
    Map<String, Object> filters,
    Integer pageNumber,
    Integer pageSize,
    String sortBy,
    String sortDirection
  ) {
    try {
      // Security check - only allow admins or users with Modify All Data permission
      if (!hasOrgWideFileAccess()) {
        throw new AuraHandledException(
          'Insufficient permissions to view org-wide files'
        );
      }
      if (pageSize == null || pageSize <= 0) {
        pageSize = 25;
      }
      if (pageNumber == null || pageNumber <= 0) {
        pageNumber = 1;
      }

      // First, we need to get ALL files to calculate usage levels, then filter and paginate
      String baseQuery = buildFileQuery(
        searchTerm,
        filters,
        sortBy,
        sortDirection
      );

      // Check if we have usage level filtering - if so, we need to process all files first
      Boolean hasUsageLevelFilter =
        filters != null &&
        filters.containsKey('usageLevel') &&
        filters.get('usageLevel') != null &&
        String.isNotBlank((String) filters.get('usageLevel'));

      List<ContentVersion> allContentVersions;
      Integer totalCount;

      if (hasUsageLevelFilter) {
        // Get all files without pagination to calculate usage levels
        allContentVersions = Database.query(baseQuery);
        System.debug('Retrieved all files count: ' + allContentVersions.size());
      } else {
        // Use normal pagination for other filters
        Integer offset = (pageNumber - 1) * pageSize;
        String paginatedQuery = baseQuery + ' LIMIT :pageSize OFFSET :offset';

        String countQuery = 'SELECT COUNT() FROM ContentVersion WHERE IsLatest = true';
        if (!String.isBlank(searchTerm)) {
          countQuery +=
            ' AND Title LIKE \'%' +
            String.escapeSingleQuotes(searchTerm) +
            '%\'';
        }
        totalCount = Database.countQuery(countQuery);
        allContentVersions = Database.query(paginatedQuery);
      }

      Set<Id> contentDocumentIds = new Set<Id>();
      for (ContentVersion cv : allContentVersions) {
        contentDocumentIds.add(cv.ContentDocumentId);
      }

      Map<Id, Integer> linkCountMap = getLinkCounts(contentDocumentIds);

      List<FileWrapper> files = new List<FileWrapper>();
      for (ContentVersion cv : allContentVersions) {
        FileWrapper fw = new FileWrapper();
        fw.contentVersionId = cv.Id;
        fw.contentDocumentId = cv.ContentDocumentId;
        fw.fileName = cv.Title;
        fw.fileType = cv.FileExtension;
        fw.fileSize = formatFileSize(cv.ContentSize);
        fw.createdBy = cv.CreatedBy.Name;
        fw.createdById = cv.CreatedById;
        fw.createdDate = cv.CreatedDate;
        fw.lastModifiedBy = cv.LastModifiedBy.Name;
        fw.lastModifiedById = cv.LastModifiedById;
        fw.lastModifiedDate = cv.LastModifiedDate;
        fw.currentOwner = cv.ContentDocument.Owner.Name;
        fw.currentOwnerId = cv.ContentDocument.OwnerId;
        fw.isOwnerActive = cv.ContentDocument.Owner.IsActive;
        fw.linkCount = linkCountMap.get(cv.ContentDocumentId) ?? 0;
        // Truly orphaned = 0 links (not attached to any records, users, or libraries)
        fw.isOrphaned = fw.linkCount == 0;

        // Set usage level based on link count
        if (fw.linkCount == 0) {
          fw.usageLevel = 'orphaned'; // 0 links = Truly Orphaned
        } else if (fw.linkCount == 1) {
          fw.usageLevel = 'low_usage'; // 1 link = Low Usage
        } else if (fw.linkCount == 2) {
          fw.usageLevel = 'lightly_connected'; // 2 links = Lightly Connected
        } else {
          fw.usageLevel = 'heavy_usage'; // 3+ links = Heavy Usage
        }
        
        // Debug: Log each file's classification
        System.debug('FILE DEBUG: ' + fw.fileName + ' -> Links: ' + fw.linkCount + ', Usage: ' + fw.usageLevel);
        fw.previewUrl =
          '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' +
          cv.Id;
        fw.downloadUrl = '/sfc/servlet.shepherd/version/download/' + cv.Id;
        files.add(fw);
      }

      // Debug: Show all filters received
      System.debug('All filters received: ' + filters);

      // Apply usage level filtering if needed
      if (hasUsageLevelFilter) {
        String targetUsageLevel = (String) filters.get('usageLevel');
        System.debug('Filtering by usage level: ' + targetUsageLevel);
        System.debug('Files before usage level filtering: ' + files.size());

        List<FileWrapper> filteredFiles = new List<FileWrapper>();
        for (FileWrapper fw : files) {
          System.debug(
            'File: ' +
              fw.fileName +
              ', Usage Level: ' +
              fw.usageLevel +
              ', Links: ' +
              fw.linkCount
          );
          if (fw.usageLevel != null && fw.usageLevel.equals(targetUsageLevel)) {
            System.debug('  -> MATCH! Adding to filtered results');
            filteredFiles.add(fw);
          } else {
            System.debug(
              '  -> No match. Expected: ' +
                targetUsageLevel +
                ', Got: ' +
                fw.usageLevel
            );
          }
        }
        files = filteredFiles;
        System.debug('Files after usage level filtering: ' + files.size());

        // Update total count for usage level filtered results
        totalCount = files.size();

        // Apply pagination to the filtered results
        Integer startIndex = (pageNumber - 1) * pageSize;
        Integer endIndex = Math.min(startIndex + pageSize, files.size());

        if (startIndex < files.size()) {
          List<FileWrapper> paginatedFiles = new List<FileWrapper>();
          for (Integer i = startIndex; i < endIndex && i < files.size(); i++) {
            paginatedFiles.add(files[i]);
          }
          files = paginatedFiles;
        } else {
          files = new List<FileWrapper>();
        }
        System.debug('Files after pagination: ' + files.size());
      } else {
        System.debug('No usage level filter applied - filters: ' + filters);
      }

      FileResult result = new FileResult();
      result.files = files;
      result.totalCount = totalCount;
      result.pageNumber = pageNumber;
      result.pageSize = pageSize;

      return result;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error retrieving files: ' + e.getMessage()
      );
    }
  }

  private static String buildFileQuery(
    String searchTerm,
    Map<String, Object> filters,
    String sortBy,
    String sortDirection
  ) {
    String query =
      'SELECT Id, ContentDocumentId, Title, FileExtension, ContentSize, ' +
      'CreatedDate, CreatedById, CreatedBy.Name, LastModifiedDate, ' +
      'LastModifiedById, LastModifiedBy.Name, ContentDocument.OwnerId, ContentDocument.Owner.Name, ContentDocument.Owner.IsActive ' +
      'FROM ContentVersion WHERE IsLatest = true';

    if (!String.isBlank(searchTerm)) {
      query +=
        ' AND Title LIKE \'%' +
        String.escapeSingleQuotes(searchTerm) +
        '%\'';
    }

    if (filters != null) {
      if (filters.containsKey('fileType') && filters.get('fileType') != null) {
        String fileType = (String) filters.get('fileType');
        query +=
          ' AND FileExtension = \'' +
          String.escapeSingleQuotes(fileType) +
          '\'';
      }

      if (filters.containsKey('ownerId') && filters.get('ownerId') != null) {
        String ownerId = (String) filters.get('ownerId');
        query +=
          ' AND CreatedById = \'' +
          String.escapeSingleQuotes(ownerId) +
          '\'';
      }

      if (
        filters.containsKey('createdDateFrom') &&
        filters.get('createdDateFrom') != null
      ) {
        String dateFrom = (String) filters.get('createdDateFrom');
        // Format date for SOQL: YYYY-MM-DD format needs to be converted to DateTime
        query += ' AND CreatedDate >= ' + dateFrom + 'T00:00:00Z';
      }

      if (
        filters.containsKey('createdDateTo') &&
        filters.get('createdDateTo') != null
      ) {
        String dateTo = (String) filters.get('createdDateTo');
        // Format date for SOQL: YYYY-MM-DD format needs to be converted to DateTime
        query += ' AND CreatedDate <= ' + dateTo + 'T23:59:59Z';
      }

      if (filters.containsKey('minSize') && filters.get('minSize') != null) {
        Decimal minSizeDecimal = (Decimal) filters.get('minSize');
        Integer minSizeKB = minSizeDecimal.intValue();
        Integer minSizeBytes = minSizeKB * 1024; // Convert KB to bytes
        query += ' AND ContentSize >= ' + minSizeBytes;
      }

      if (filters.containsKey('maxSize') && filters.get('maxSize') != null) {
        Decimal maxSizeDecimal = (Decimal) filters.get('maxSize');
        Integer maxSizeKB = maxSizeDecimal.intValue();
        Integer maxSizeBytes = maxSizeKB * 1024; // Convert KB to bytes
        query += ' AND ContentSize <= ' + maxSizeBytes;
      }

      if (filters.containsKey('inactiveOwners') && filters.get('inactiveOwners') != null) {
        Boolean showInactiveOwners = (Boolean) filters.get('inactiveOwners');
        if (showInactiveOwners) {
          query += ' AND ContentDocument.Owner.IsActive = false';
        }
      }
    }

    // Note: Usage level filtering (orphaned, low_usage, well_connected)
    // is applied post-query since it depends on link count calculation

    if (!String.isBlank(sortBy)) {
      query += ' ORDER BY ' + sortBy;
      if (!String.isBlank(sortDirection)) {
        query += ' ' + sortDirection;
      }
    } else {
      query += ' ORDER BY CreatedDate DESC';
    }

    return query;
  }

  private static Map<Id, Integer> getLinkCounts(Set<Id> contentDocumentIds) {
    Map<Id, Integer> linkCountMap = new Map<Id, Integer>();

    List<AggregateResult> linkCounts = [
      SELECT ContentDocumentId, COUNT(Id) linkCount
      FROM ContentDocumentLink
      WHERE ContentDocumentId IN :contentDocumentIds
      GROUP BY ContentDocumentId
    ];

    for (AggregateResult ar : linkCounts) {
      linkCountMap.put(
        (Id) ar.get('ContentDocumentId'),
        (Integer) ar.get('linkCount')
      );
    }

    return linkCountMap;
  }

  @AuraEnabled
  public static void deleteFiles(List<Id> contentDocumentIds) {
    try {
      if (!hasOrgWideFileAccess()) {
        throw new AuraHandledException(
          'Insufficient permissions to delete org-wide files'
        );
      }
      if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
        throw new AuraHandledException('No files selected for deletion');
      }

      List<ContentDocument> docsToDelete = [
        SELECT Id
        FROM ContentDocument
        WHERE Id IN :contentDocumentIds
      ];

      if (!docsToDelete.isEmpty()) {
        delete docsToDelete;
      }
    } catch (Exception e) {
      throw new AuraHandledException('Error deleting files: ' + e.getMessage());
    }
  }

  @AuraEnabled
  public static void reassignFileOwner(Id contentDocumentId, Id newOwnerId) {
    try {
      if (!hasOrgWideFileAccess()) {
        throw new AuraHandledException(
          'Insufficient permissions to reassign file owners'
        );
      }
      ContentDocument doc = [
        SELECT Id, OwnerId
        FROM ContentDocument
        WHERE Id = :contentDocumentId
        LIMIT 1
      ];

      doc.OwnerId = newOwnerId;
      update doc;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error reassigning file owner: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled
  public static void bulkReassignFileOwner(List<Id> contentDocumentIds, Id newOwnerId) {
    try {
      if (!hasOrgWideFileAccess()) {
        throw new AuraHandledException(
          'Insufficient permissions to reassign file owners'
        );
      }

      if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
        throw new AuraHandledException('No files selected for ownership transfer');
      }

      List<ContentDocument> docs = [
        SELECT Id, OwnerId
        FROM ContentDocument
        WHERE Id IN :contentDocumentIds
      ];

      for (ContentDocument doc : docs) {
        doc.OwnerId = newOwnerId;
      }

      update docs;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error reassigning file owners: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled
  public static void detachAllLinks(Id contentDocumentId) {
    try {
      if (!hasOrgWideFileAccess()) {
        throw new AuraHandledException(
          'Insufficient permissions to detach file links'
        );
      }
      List<ContentDocumentLink> links = [
        SELECT Id
        FROM ContentDocumentLink
        WHERE ContentDocumentId = :contentDocumentId
      ];

      if (!links.isEmpty()) {
        delete links;
      }
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error detaching file links: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled
  public static void shareWithUser(Id contentDocumentId, Id userId) {
    try {
      if (!hasOrgWideFileAccess()) {
        throw new AuraHandledException(
          'Insufficient permissions to share files'
        );
      }

      // Check if the link already exists
      List<ContentDocumentLink> existingLinks = [
        SELECT Id
        FROM ContentDocumentLink
        WHERE ContentDocumentId = :contentDocumentId
        AND LinkedEntityId = :userId
        LIMIT 1
      ];

      if (existingLinks.isEmpty()) {
        // Create new ContentDocumentLink to share with user
        ContentDocumentLink newLink = new ContentDocumentLink();
        newLink.ContentDocumentId = contentDocumentId;
        newLink.LinkedEntityId = userId;
        newLink.ShareType = 'V'; // Viewer permission
        newLink.Visibility = 'AllUsers';
        
        insert newLink;
      }
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error sharing file with user: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled
  public static void bulkShareWithUser(List<Id> contentDocumentIds, Id userId) {
    try {
      if (!hasOrgWideFileAccess()) {
        throw new AuraHandledException(
          'Insufficient permissions to share files'
        );
      }

      // Get existing links to avoid duplicates
      Set<Id> existingContentDocumentIds = new Set<Id>();
      List<ContentDocumentLink> existingLinks = [
        SELECT ContentDocumentId
        FROM ContentDocumentLink
        WHERE ContentDocumentId IN :contentDocumentIds
        AND LinkedEntityId = :userId
      ];
      
      for (ContentDocumentLink link : existingLinks) {
        existingContentDocumentIds.add(link.ContentDocumentId);
      }

      // Create new links for files that don't have existing links
      List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
      for (Id contentDocumentId : contentDocumentIds) {
        if (!existingContentDocumentIds.contains(contentDocumentId)) {
          ContentDocumentLink newLink = new ContentDocumentLink();
          newLink.ContentDocumentId = contentDocumentId;
          newLink.LinkedEntityId = userId;
          newLink.ShareType = 'V'; // Viewer permission
          newLink.Visibility = 'AllUsers';
          newLinks.add(newLink);
        }
      }
      
      if (!newLinks.isEmpty()) {
        insert newLinks;
      }
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error sharing files: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled
  public static List<Map<String, Object>> getFileConnections(Id contentDocumentId) {
    try {
      if (!hasOrgWideFileAccess()) {
        throw new AuraHandledException(
          'Insufficient permissions to view file connections'
        );
      }

      List<Map<String, Object>> connections = new List<Map<String, Object>>();
      
      // Get all ContentDocumentLinks for this file
      List<ContentDocumentLink> links = [
        SELECT Id, LinkedEntityId, LinkedEntity.Type, LinkedEntity.Name, 
               ShareType, Visibility, IsDeleted
        FROM ContentDocumentLink 
        WHERE ContentDocumentId = :contentDocumentId
        AND IsDeleted = false
      ];

      // Get additional details for specific entity types
      Map<Id, SObject> recordDetails = new Map<Id, SObject>();
      Set<Id> userIds = new Set<Id>();
      Set<Id> accountIds = new Set<Id>();
      Set<Id> contactIds = new Set<Id>();
      Set<Id> opportunityIds = new Set<Id>();
      Set<Id> caseIds = new Set<Id>();
      Set<Id> leadIds = new Set<Id>();

      // Categorize entity IDs
      for (ContentDocumentLink link : links) {
        String entityType = link.LinkedEntity.Type;
        Id entityId = link.LinkedEntityId;
        
        if (entityType == 'User') {
          userIds.add(entityId);
        } else if (entityType == 'Account') {
          accountIds.add(entityId);
        } else if (entityType == 'Contact') {
          contactIds.add(entityId);
        } else if (entityType == 'Opportunity') {
          opportunityIds.add(entityId);
        } else if (entityType == 'Case') {
          caseIds.add(entityId);
        } else if (entityType == 'Lead') {
          leadIds.add(entityId);
        }
      }

      // Query additional details for each entity type
      if (!userIds.isEmpty()) {
        for (User u : [SELECT Id, Name, Email, Username, Title, Department FROM User WHERE Id IN :userIds]) {
          recordDetails.put(u.Id, u);
        }
      }
      if (!accountIds.isEmpty()) {
        for (Account a : [SELECT Id, Name, Type, Industry, BillingCity, BillingState FROM Account WHERE Id IN :accountIds]) {
          recordDetails.put(a.Id, a);
        }
      }
      if (!contactIds.isEmpty()) {
        for (Contact c : [SELECT Id, Name, Email, Title, Department, Account.Name FROM Contact WHERE Id IN :contactIds]) {
          recordDetails.put(c.Id, c);
        }
      }
      if (!opportunityIds.isEmpty()) {
        for (Opportunity o : [SELECT Id, Name, StageName, Amount, CloseDate, Account.Name FROM Opportunity WHERE Id IN :opportunityIds]) {
          recordDetails.put(o.Id, o);
        }
      }
      if (!caseIds.isEmpty()) {
        for (Case cs : [SELECT Id, CaseNumber, Subject, Status, Priority, Account.Name, Contact.Name FROM Case WHERE Id IN :caseIds]) {
          recordDetails.put(cs.Id, cs);
        }
      }
      if (!leadIds.isEmpty()) {
        for (Lead l : [SELECT Id, Name, Email, Company, Status, LeadSource FROM Lead WHERE Id IN :leadIds]) {
          recordDetails.put(l.Id, l);
        }
      }

      for (ContentDocumentLink link : links) {
        Map<String, Object> connection = new Map<String, Object>();
        String entityType = link.LinkedEntity.Type;
        String entityName = link.LinkedEntity.Name;
        String entityId = link.LinkedEntityId;
        String url = '';
        String icon = 'standard:record';
        String description = '';
        String subtitle = '';
        String additionalInfo = '';

        // Get detailed record information
        SObject recordDetail = recordDetails.get(entityId);

        // Generate URLs, set icons, and build detailed descriptions based on entity type
        if (entityType == 'User') {
          url = '/' + entityId;
          icon = 'standard:user';
          description = 'Shared with user';
          if (recordDetail != null) {
            User u = (User) recordDetail;
            subtitle = u.Email;
            additionalInfo = (u.Title != null ? u.Title : '') + 
                           (u.Department != null ? ' • ' + u.Department : '');
          }
        } else if (entityType == 'Account') {
          url = '/' + entityId;
          icon = 'standard:account';
          description = 'Attached to account';
          if (recordDetail != null) {
            Account a = (Account) recordDetail;
            subtitle = a.Type;
            additionalInfo = (a.Industry != null ? a.Industry : '') + 
                           (a.BillingCity != null ? ' • ' + a.BillingCity : '') +
                           (a.BillingState != null ? ', ' + a.BillingState : '');
          }
        } else if (entityType == 'Contact') {
          url = '/' + entityId;
          icon = 'standard:contact';
          description = 'Attached to contact';
          if (recordDetail != null) {
            Contact c = (Contact) recordDetail;
            subtitle = c.Email;
            additionalInfo = (c.Title != null ? c.Title : '') + 
                           (c.Account != null && c.Account.Name != null ? ' • ' + c.Account.Name : '');
          }
        } else if (entityType == 'Opportunity') {
          url = '/' + entityId;
          icon = 'standard:opportunity';
          description = 'Attached to opportunity';
          if (recordDetail != null) {
            Opportunity o = (Opportunity) recordDetail;
            subtitle = o.StageName;
            additionalInfo = (o.Amount != null ? '$' + o.Amount.format() : '') + 
                           (o.Account != null && o.Account.Name != null ? ' • ' + o.Account.Name : '') +
                           (o.CloseDate != null ? ' • ' + o.CloseDate.format() : '');
          }
        } else if (entityType == 'Case') {
          url = '/' + entityId;
          icon = 'standard:case';
          description = 'Attached to case';
          if (recordDetail != null) {
            Case cs = (Case) recordDetail;
            subtitle = 'Case #' + cs.CaseNumber + ' • ' + cs.Status;
            additionalInfo = (cs.Priority != null ? cs.Priority + ' Priority' : '') + 
                           (cs.Account != null && cs.Account.Name != null ? ' • ' + cs.Account.Name : '');
          }
        } else if (entityType == 'Lead') {
          url = '/' + entityId;
          icon = 'standard:lead';
          description = 'Attached to lead';
          if (recordDetail != null) {
            Lead l = (Lead) recordDetail;
            subtitle = l.Company + ' • ' + l.Status;
            additionalInfo = (l.Email != null ? l.Email : '') + 
                           (l.LeadSource != null ? ' • ' + l.LeadSource : '');
          }
        } else if (entityType == 'ContentWorkspace') {
          url = '/lightning/r/ContentWorkspace/' + entityId + '/view';
          icon = 'standard:file';
          description = 'In library';
        } else if (entityType == 'CollaborationGroup') {
          url = '/lightning/r/CollaborationGroup/' + entityId + '/view';
          icon = 'standard:groups';
          description = 'Shared with group';
        } else if (entityType == 'EmailMessage') {
          url = '/' + entityId;
          icon = 'standard:email';
          description = 'Email attachment';
        } else {
          // Generic fallback for other object types
          url = '/' + entityId;
          icon = 'standard:record';
          description = 'Attached to ' + entityType.toLowerCase();
        }

        connection.put('id', link.Id);
        connection.put('entityId', entityId);
        connection.put('entityType', entityType);
        connection.put('entityName', entityName);
        connection.put('url', url);
        connection.put('icon', icon);
        connection.put('description', description);
        connection.put('subtitle', subtitle);
        connection.put('additionalInfo', additionalInfo);
        connection.put('shareType', link.ShareType);
        connection.put('visibility', link.Visibility);
        
        connections.add(connection);
      }

      return connections;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error retrieving file connections: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getActiveUsers() {
    List<Map<String, String>> users = new List<Map<String, String>>();

    List<User> activeUsers = [
      SELECT Id, Name, Username
      FROM User
      WHERE IsActive = TRUE
      ORDER BY Name
      LIMIT 100
    ];

    for (User u : activeUsers) {
      Map<String, String> user = new Map<String, String>();
      user.put('value', u.Id);
      user.put('label', u.Name + ' (' + u.Username + ')');
      users.add(user);
    }

    return users;
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getFileTypes() {
    List<Map<String, String>> fileTypes = new List<Map<String, String>>();

    List<AggregateResult> results = [
      SELECT FileExtension, COUNT(Id) fileCount
      FROM ContentVersion
      WHERE IsLatest = TRUE AND FileExtension != NULL
      GROUP BY FileExtension
      ORDER BY COUNT(Id) DESC
      LIMIT 20
    ];

    for (AggregateResult ar : results) {
      Map<String, String> fileType = new Map<String, String>();
      fileType.put('value', (String) ar.get('FileExtension'));
      fileType.put(
        'label',
        (String) ar.get('FileExtension') + ' (' + ar.get('fileCount') + ')'
      );
      fileTypes.add(fileType);
    }

    return fileTypes;
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getFileOwners() {
    List<Map<String, String>> owners = new List<Map<String, String>>();

    List<AggregateResult> results = [
      SELECT CreatedById, CreatedBy.Name userName, COUNT(Id) fileCount
      FROM ContentVersion
      WHERE IsLatest = TRUE
      GROUP BY CreatedById, CreatedBy.Name
      ORDER BY COUNT(Id) DESC
      LIMIT 50
    ];

    for (AggregateResult ar : results) {
      Map<String, String> owner = new Map<String, String>();
      owner.put('value', (String) ar.get('CreatedById'));
      owner.put(
        'label',
        (String) ar.get('userName') + ' (' + ar.get('fileCount') + ')'
      );
      owners.add(owner);
    }

    return owners;
  }

  private static String formatFileSize(Integer contentSize) {
    if (contentSize == null) {
      return '0 B';
    }

    Double size = contentSize;
    String[] units = new List<String>{ 'B', 'KB', 'MB', 'GB', 'TB' };
    Integer unitIndex = 0;

    while (size >= 1024 && unitIndex < units.size() - 1) {
      size /= 1024;
      unitIndex++;
    }

    return String.valueOf(Math.round(size * 100) / 100.0) +
      ' ' +
      units[unitIndex];
  }

  private static Boolean hasOrgWideFileAccess() {
    // Check if user has System Administrator profile or Modify All Data permission
    User currentUser = [
      SELECT Profile.Name, Profile.PermissionsModifyAllData
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];

    return currentUser.Profile.Name == 'System Administrator' ||
      currentUser.Profile.PermissionsModifyAllData ||
      FeatureManagement.checkPermission('ViewAllFiles'); // Custom permission if created
  }
}
