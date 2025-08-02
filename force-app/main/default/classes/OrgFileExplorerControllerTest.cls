@IsTest
public class OrgFileExplorerControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test users
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        User testUser1 = new User(
            FirstName = 'Test',
            LastName = 'User1',
            Email = 'testuser1@test.com',
            Username = 'testuser1@test.com.fileexplorer',
            Alias = 'tuser1',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = adminProfile.Id,
            IsActive = true
        );
        insert testUser1;
        
        User testUser2 = new User(
            FirstName = 'Test',
            LastName = 'User2',
            Email = 'testuser2@test.com',
            Username = 'testuser2@test.com.fileexplorer',
            Alias = 'tuser2',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = adminProfile.Id,
            IsActive = false
        );
        insert testUser2;
        
        // Create test account for file attachments
        Account testAccount = new Account(
            Name = 'Test Account',
            Type = 'Customer',
            Industry = 'Technology'
        );
        insert testAccount;
        
        // Create test contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'testcontact@test.com',
            AccountId = testAccount.Id
        );
        insert testContact;
    }
    
    static List<ContentVersion> createTestContentVersions(Integer count) {
        List<ContentVersion> contentVersions = new List<ContentVersion>();
        
        for (Integer i = 0; i < count; i++) {
            ContentVersion cv = new ContentVersion(
                Title = 'Test File ' + i,
                PathOnClient = 'TestFile' + i + '.txt',
                VersionData = Blob.valueOf('Test file content ' + i),
                FirstPublishLocationId = UserInfo.getUserId()
            );
            contentVersions.add(cv);
        }
        
        insert contentVersions;
        return contentVersions;
    }
    
    static void createTestContentDocumentLinks(List<ContentVersion> contentVersions, List<Id> entityIds) {
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        
        for (Integer i = 0; i < contentVersions.size() && i < entityIds.size(); i++) {
            ContentDocumentLink link = new ContentDocumentLink(
                ContentDocumentId = contentVersions[i].ContentDocumentId,
                LinkedEntityId = entityIds[i],
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            links.add(link);
        }
        
        if (!links.isEmpty()) {
            insert links;
        }
    }
    
    @IsTest
    static void testGetOrgFiles_BasicFunctionality() {
        Test.startTest();
        
        List<ContentVersion> testFiles = createTestContentVersions(5);
        
        OrgFileExplorerController.FileResult result = OrgFileExplorerController.getOrgFiles(
            null, // searchTerm
            null, // filters
            1,    // pageNumber
            25,   // pageSize
            'CreatedDate', // sortBy
            'DESC' // sortDirection
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.pageNumber, 'Page number should be 1');
        System.assertEquals(25, result.pageSize, 'Page size should be 25');
        System.assert(result.files.size() >= 5, 'Should contain at least the 5 test files');
    }
    
    @IsTest
    static void testGetOrgFiles_WithSearchTerm() {
        Test.startTest();
        
        List<ContentVersion> testFiles = createTestContentVersions(3);
        testFiles[0].Title = 'Special Document';
        update testFiles[0];
        
        OrgFileExplorerController.FileResult result = OrgFileExplorerController.getOrgFiles(
            'Special', // searchTerm
            null,      // filters
            1,         // pageNumber
            25,        // pageSize
            'CreatedDate', // sortBy
            'DESC'     // sortDirection
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        Boolean foundSpecialFile = false;
        for (OrgFileExplorerController.FileWrapper fw : result.files) {
            if (fw.fileName.contains('Special')) {
                foundSpecialFile = true;
                break;
            }
        }
        System.assert(foundSpecialFile, 'Should find the special document');
    }
    
    @IsTest
    static void testGetOrgFiles_WithFilters() {
        Test.startTest();
        
        List<ContentVersion> testFiles = createTestContentVersions(3);
        
        Map<String, Object> filters = new Map<String, Object>();
        filters.put('fileType', 'txt');
        
        OrgFileExplorerController.FileResult result = OrgFileExplorerController.getOrgFiles(
            null,    // searchTerm
            filters, // filters
            1,       // pageNumber
            25,      // pageSize
            'CreatedDate', // sortBy
            'DESC'   // sortDirection
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        for (OrgFileExplorerController.FileWrapper fw : result.files) {
            if (fw.fileType != null) {
                System.assertEquals('txt', fw.fileType, 'All files should be txt files');
            }
        }
    }
    
    @IsTest
    static void testGetOrgFiles_WithUsageLevelFilter() {
        Test.startTest();
        
        List<ContentVersion> testFiles = createTestContentVersions(3);
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        
        if (!accounts.isEmpty()) {
            List<Id> entityIds = new List<Id>{ accounts[0].Id };
            createTestContentDocumentLinks(new List<ContentVersion>{ testFiles[0] }, entityIds);
        }
        
        Map<String, Object> filters = new Map<String, Object>();
        filters.put('usageLevel', 'orphaned');
        
        OrgFileExplorerController.FileResult result = OrgFileExplorerController.getOrgFiles(
            null,    // searchTerm
            filters, // filters
            1,       // pageNumber
            25,      // pageSize
            'CreatedDate', // sortBy
            'DESC'   // sortDirection
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        for (OrgFileExplorerController.FileWrapper fw : result.files) {
            System.assertEquals('orphaned', fw.usageLevel, 'All files should be orphaned');
        }
    }
    
    @IsTest
    static void testGetOrgFiles_Pagination() {
        Test.startTest();
        
        createTestContentVersions(10);
        
        OrgFileExplorerController.FileResult page1 = OrgFileExplorerController.getOrgFiles(
            null, null, 1, 5, 'CreatedDate', 'DESC'
        );
        
        OrgFileExplorerController.FileResult page2 = OrgFileExplorerController.getOrgFiles(
            null, null, 2, 5, 'CreatedDate', 'DESC'
        );
        
        Test.stopTest();
        
        System.assertEquals(1, page1.pageNumber, 'First page number should be 1');
        System.assertEquals(2, page2.pageNumber, 'Second page number should be 2');
        System.assertEquals(5, page1.pageSize, 'Page size should be 5');
        System.assertEquals(5, page2.pageSize, 'Page size should be 5');
    }
    
    @IsTest
    static void testDeleteFiles_Success() {
        Test.startTest();
        
        List<ContentVersion> testFiles = createTestContentVersions(3);
        List<Id> contentDocumentIds = new List<Id>();
        for (ContentVersion cv : testFiles) {
            contentDocumentIds.add(cv.ContentDocumentId);
        }
        
        OrgFileExplorerController.deleteFiles(contentDocumentIds);
        
        Test.stopTest();
        
        List<ContentDocument> remainingDocs = [
            SELECT Id FROM ContentDocument WHERE Id IN :contentDocumentIds
        ];
        System.assertEquals(0, remainingDocs.size(), 'All files should be deleted');
    }
    
    @IsTest
    static void testDeleteFiles_EmptyList() {
        Test.startTest();
        
        try {
            OrgFileExplorerController.deleteFiles(new List<Id>());
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('No files selected'), 'Should throw appropriate error message');
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testReassignFileOwner_Success() {
        Test.startTest();
        
        List<ContentVersion> testFiles = createTestContentVersions(1);
        List<User> testUsers = [SELECT Id FROM User WHERE FirstName = 'Test' AND LastName = 'User1' LIMIT 1];
        
        if (!testUsers.isEmpty()) {
            OrgFileExplorerController.reassignFileOwner(testFiles[0].ContentDocumentId, testUsers[0].Id);
            
            ContentDocument doc = [
                SELECT Id, OwnerId 
                FROM ContentDocument 
                WHERE Id = :testFiles[0].ContentDocumentId
            ];
            
            System.assertEquals(testUsers[0].Id, doc.OwnerId, 'Owner should be updated');
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testBulkReassignFileOwner_Success() {
        Test.startTest();
        
        List<ContentVersion> testFiles = createTestContentVersions(3);
        List<User> testUsers = [SELECT Id FROM User WHERE FirstName = 'Test' AND LastName = 'User1' LIMIT 1];
        
        if (!testUsers.isEmpty()) {
            List<Id> contentDocumentIds = new List<Id>();
            for (ContentVersion cv : testFiles) {
                contentDocumentIds.add(cv.ContentDocumentId);
            }
            
            OrgFileExplorerController.bulkReassignFileOwner(contentDocumentIds, testUsers[0].Id);
            
            List<ContentDocument> docs = [
                SELECT Id, OwnerId 
                FROM ContentDocument 
                WHERE Id IN :contentDocumentIds
            ];
            
            for (ContentDocument doc : docs) {
                System.assertEquals(testUsers[0].Id, doc.OwnerId, 'All owners should be updated');
            }
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testShareWithUser_Success() {
        Test.startTest();
        
        List<ContentVersion> testFiles = createTestContentVersions(1);
        List<User> testUsers = [SELECT Id FROM User WHERE FirstName = 'Test' AND LastName = 'User1' LIMIT 1];
        
        if (!testUsers.isEmpty()) {
            OrgFileExplorerController.shareWithUser(testFiles[0].ContentDocumentId, testUsers[0].Id);
            
            List<ContentDocumentLink> links = [
                SELECT Id FROM ContentDocumentLink
                WHERE ContentDocumentId = :testFiles[0].ContentDocumentId
                AND LinkedEntityId = :testUsers[0].Id
            ];
            
            System.assertEquals(1, links.size(), 'Should create one sharing link');
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testShareWithUser_DuplicateLink() {
        Test.startTest();
        
        List<ContentVersion> testFiles = createTestContentVersions(1);
        List<User> testUsers = [SELECT Id FROM User WHERE FirstName = 'Test' AND LastName = 'User1' LIMIT 1];
        
        if (!testUsers.isEmpty()) {
            // Share twice
            OrgFileExplorerController.shareWithUser(testFiles[0].ContentDocumentId, testUsers[0].Id);
            OrgFileExplorerController.shareWithUser(testFiles[0].ContentDocumentId, testUsers[0].Id);
            
            List<ContentDocumentLink> links = [
                SELECT Id FROM ContentDocumentLink
                WHERE ContentDocumentId = :testFiles[0].ContentDocumentId
                AND LinkedEntityId = :testUsers[0].Id
            ];
            
            System.assertEquals(1, links.size(), 'Should not create duplicate links');
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testBulkShareWithUser_Success() {
        Test.startTest();
        
        List<ContentVersion> testFiles = createTestContentVersions(3);
        List<User> testUsers = [SELECT Id FROM User WHERE FirstName = 'Test' AND LastName = 'User1' LIMIT 1];
        
        if (!testUsers.isEmpty()) {
            List<Id> contentDocumentIds = new List<Id>();
            for (ContentVersion cv : testFiles) {
                contentDocumentIds.add(cv.ContentDocumentId);
            }
            
            OrgFileExplorerController.bulkShareWithUser(contentDocumentIds, testUsers[0].Id);
            
            List<ContentDocumentLink> links = [
                SELECT Id FROM ContentDocumentLink
                WHERE ContentDocumentId IN :contentDocumentIds
                AND LinkedEntityId = :testUsers[0].Id
            ];
            
            System.assertEquals(3, links.size(), 'Should create three sharing links');
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testDetachAllLinks_Success() {
        Test.startTest();
        
        List<ContentVersion> testFiles = createTestContentVersions(1);
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        
        if (!accounts.isEmpty()) {
            createTestContentDocumentLinks(testFiles, new List<Id>{ accounts[0].Id });
            
            OrgFileExplorerController.detachAllLinks(testFiles[0].ContentDocumentId);
            
            List<ContentDocumentLink> remainingLinks = [
                SELECT Id FROM ContentDocumentLink
                WHERE ContentDocumentId = :testFiles[0].ContentDocumentId
            ];
            
            System.assertEquals(0, remainingLinks.size(), 'All links should be deleted');
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetFileConnections_Success() {
        Test.startTest();
        
        List<ContentVersion> testFiles = createTestContentVersions(1);
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 1];
        
        if (!accounts.isEmpty() && !contacts.isEmpty()) {
            createTestContentDocumentLinks(testFiles, new List<Id>{ accounts[0].Id });
            createTestContentDocumentLinks(testFiles, new List<Id>{ contacts[0].Id });
            
            List<Map<String, Object>> connections = OrgFileExplorerController.getFileConnections(
                testFiles[0].ContentDocumentId
            );
            
            System.assert(connections.size() >= 2, 'Should have at least 2 connections');
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetActiveUsers_Success() {
        Test.startTest();
        
        List<Map<String, String>> users = OrgFileExplorerController.getActiveUsers();
        
        Test.stopTest();
        
        System.assertNotEquals(null, users, 'Users list should not be null');
        System.assert(users.size() > 0, 'Should return at least one active user');
        
        for (Map<String, String> user : users) {
            System.assert(user.containsKey('value'), 'User should have value key');
            System.assert(user.containsKey('label'), 'User should have label key');
        }
    }
    
    @IsTest
    static void testGetFileTypes_Success() {
        Test.startTest();
        
        createTestContentVersions(3);
        
        List<Map<String, String>> fileTypes = OrgFileExplorerController.getFileTypes();
        
        Test.stopTest();
        
        System.assertNotEquals(null, fileTypes, 'File types list should not be null');
        
        for (Map<String, String> fileType : fileTypes) {
            System.assert(fileType.containsKey('value'), 'File type should have value key');
            System.assert(fileType.containsKey('label'), 'File type should have label key');
        }
    }
    
    @IsTest
    static void testGetFileOwners_Success() {
        Test.startTest();
        
        createTestContentVersions(3);
        
        List<Map<String, String>> owners = OrgFileExplorerController.getFileOwners();
        
        Test.stopTest();
        
        System.assertNotEquals(null, owners, 'Owners list should not be null');
        
        for (Map<String, String> owner : owners) {
            System.assert(owner.containsKey('value'), 'Owner should have value key');
            System.assert(owner.containsKey('label'), 'Owner should have label key');
        }
    }
    
    @IsTest
    static void testUsageLevelClassification() {
        Test.startTest();
        
        List<ContentVersion> testFiles = createTestContentVersions(4);
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 1];
        
        if (!accounts.isEmpty() && !contacts.isEmpty()) {
            // File 0: No links (orphaned)
            // File 1: 1 link (low_usage)
            createTestContentDocumentLinks(new List<ContentVersion>{ testFiles[1] }, new List<Id>{ accounts[0].Id });
            
            // File 2: 2 links (lightly_connected)
            createTestContentDocumentLinks(new List<ContentVersion>{ testFiles[2] }, new List<Id>{ accounts[0].Id });
            createTestContentDocumentLinks(new List<ContentVersion>{ testFiles[2] }, new List<Id>{ contacts[0].Id });
            
            // File 3: 3+ links (heavy_usage) - we'll add the user link plus account and contact
            createTestContentDocumentLinks(new List<ContentVersion>{ testFiles[3] }, new List<Id>{ accounts[0].Id });
            createTestContentDocumentLinks(new List<ContentVersion>{ testFiles[3] }, new List<Id>{ contacts[0].Id });
            createTestContentDocumentLinks(new List<ContentVersion>{ testFiles[3] }, new List<Id>{ UserInfo.getUserId() });
            
            OrgFileExplorerController.FileResult result = OrgFileExplorerController.getOrgFiles(
                null, null, 1, 10, 'CreatedDate', 'DESC'
            );
            
            Map<Id, String> usageLevelMap = new Map<Id, String>();
            for (OrgFileExplorerController.FileWrapper fw : result.files) {
                usageLevelMap.put(fw.contentDocumentId, fw.usageLevel);
            }
            
            System.assertEquals('orphaned', usageLevelMap.get(testFiles[0].ContentDocumentId), 'File 0 should be orphaned');
            System.assertEquals('low_usage', usageLevelMap.get(testFiles[1].ContentDocumentId), 'File 1 should be low usage');
            System.assertEquals('lightly_connected', usageLevelMap.get(testFiles[2].ContentDocumentId), 'File 2 should be lightly connected');
            System.assertEquals('heavy_usage', usageLevelMap.get(testFiles[3].ContentDocumentId), 'File 3 should be heavy usage');
        }
        
        Test.stopTest();
    }
}