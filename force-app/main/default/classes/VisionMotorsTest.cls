@IsTest
private class VisionMotorsTest {
    @TestSetup static void data() {
        Vehicle_Dealer__c d = new Vehicle_Dealer__c(Name='Vision Chennai', Dealer_Name__c='Vision Chennai', Dealer_Location__c='Chennai'); insert d;
        insert new Vehicle_Customer__c(Name='Sample Customer', Customer_Name__c='Sample Customer', Address__c='Chennai', Email__c='customer@example.invalid');
        insert new List<Vehicle__c>{
            new Vehicle__c(Name='Available SUV', Stock_Quantity__c=5, Status__c='Available', Dealer__c=d.Id),
            new Vehicle__c(Name='Empty EV', Stock_Quantity__c=0, Status__c='Out of Stock', Dealer__c=d.Id),
            new Vehicle__c(Name='Discontinued Sedan', Stock_Quantity__c=3, Status__c='Discontinued', Dealer__c=d.Id)
        };
    }
    private static Vehicle__c vehicle(String name) {
        return [SELECT Id, Stock_Quantity__c, Status__c, Dealer__c FROM Vehicle__c WHERE Name=:name LIMIT 1];
    }
    private static Id customer() { return [SELECT Id FROM Vehicle_Customer__c LIMIT 1].Id; }
    private static Vehicle_Order__c order(Id vehicleId, String status) {
        return new Vehicle_Order__c(Name='Sample Order', Vehicle__c=vehicleId, Vehicle_Customer__c=customer(), Status__c=status);
    }
    @IsTest static void stockTransitions() {
        Vehicle__c v=vehicle('Available SUV'); Vehicle_Order__c o=order(v.Id,'Confirmed'); insert o;
        System.assertEquals(4, vehicle('Available SUV').Stock_Quantity__c);
        o=[SELECT Id, Dealer__c, Order_Date__c, Status__c FROM Vehicle_Order__c WHERE Id=:o.Id];
        System.assertEquals(v.Dealer__c,o.Dealer__c); System.assertEquals(Date.today(),o.Order_Date__c);
        o.Order_Date__c=Date.today().addDays(1); update o;
        System.assertEquals(4,vehicle('Available SUV').Stock_Quantity__c,'Ordinary updates must not deduct stock again');
        o.Status__c='Delivered'; update o; System.assertEquals(4,vehicle('Available SUV').Stock_Quantity__c);
        o.Status__c='Canceled'; update o; System.assertEquals(5,vehicle('Available SUV').Stock_Quantity__c);
    }
    @IsTest static void unavailableAndRequiredFields() {
        Database.SaveResult empty=Database.insert(order(vehicle('Empty EV').Id,'Pending'),false);
        System.assert(!empty.isSuccess()); System.assert(empty.getErrors()[0].getMessage().contains('out of stock'));
        System.assert(!Database.insert(order(vehicle('Discontinued Sedan').Id,'Confirmed'),false).isSuccess());
        System.assert(!Database.insert(new Vehicle_Order__c(Name='Incomplete'),false).isSuccess());
    }
    @IsTest static void bulkCapacity() {
        Vehicle__c v=vehicle('Available SUV'); v.Stock_Quantity__c=1; update v;
        List<Vehicle_Order__c> orders=new List<Vehicle_Order__c>{order(v.Id,'Confirmed'),order(v.Id,'Confirmed')};
        Database.SaveResult[] results=Database.insert(orders,false);
        Integer successes=0; for(Database.SaveResult r:results) if(r.isSuccess()) successes++;
        System.assertEquals(1,successes); System.assertEquals(0,vehicle('Available SUV').Stock_Quantity__c);
        System.assertEquals('Out of Stock',vehicle('Available SUV').Status__c);
    }
    @IsTest static void bulkTwoHundred() {
        Vehicle__c v=vehicle('Available SUV'); v.Stock_Quantity__c=200; update v;
        Id c=customer(); List<Vehicle_Order__c> orders=new List<Vehicle_Order__c>();
        for(Integer i=0;i<200;i++)orders.add(new Vehicle_Order__c(Name='Bulk '+i,Vehicle__c=v.Id,Vehicle_Customer__c=c,Status__c='Confirmed'));
        insert orders; System.assertEquals(0,vehicle('Available SUV').Stock_Quantity__c);
    }
    @IsTest static void fallbackDealerAndDefaults() {
        Vehicle_Customer__c c=[SELECT Id,Address__c FROM Vehicle_Customer__c LIMIT 1]; c.Address__c='Other city'; update c;
        Vehicle__c v=vehicle('Available SUV'); Vehicle_Order__c o=order(v.Id,null); insert o;
        o=[SELECT Dealer__c,Status__c FROM Vehicle_Order__c WHERE Id=:o.Id];
        System.assertEquals(v.Dealer__c,o.Dealer__c); System.assertEquals('Pending',o.Status__c);
        System.assertEquals(5,vehicle('Available SUV').Stock_Quantity__c);
    }
    @IsTest static void reservedVehicleCannotChange() {
        Vehicle_Order__c o=order(vehicle('Available SUV').Id,'Confirmed'); insert o;
        o.Vehicle__c=vehicle('Discontinued Sedan').Id; System.assert(!Database.update(o,false).isSuccess());
    }
    @IsTest static void pendingBatch() {
        Vehicle__c v=vehicle('Available SUV'); v.Stock_Quantity__c=1; update v;
        insert new List<Vehicle_Order__c>{order(v.Id,'Pending'),order(v.Id,'Pending')};
        Test.startTest(); Database.executeBatch(new VehicleOrderBatch(),50); Test.stopTest();
        System.assertEquals(1,[SELECT count() FROM Vehicle_Order__c WHERE Status__c='Confirmed']);
        System.assertEquals(1,[SELECT count() FROM Vehicle_Order__c WHERE Status__c='Pending']);
        System.assertEquals(0,vehicle('Available SUV').Stock_Quantity__c);
    }
    @IsTest static void inventoryBatch() {
        Vehicle__c available=vehicle('Available SUV'); available.Status__c='Out of Stock'; update available;
        Vehicle__c empty=vehicle('Empty EV'); empty.Status__c='Available'; update empty;
        Test.startTest(); Database.executeBatch(new VehicleStockBatch(),200); Test.stopTest();
        System.assertEquals('Available',vehicle('Available SUV').Status__c);
        System.assertEquals('Out of Stock',vehicle('Empty EV').Status__c);
        System.assertEquals('Discontinued',vehicle('Discontinued Sedan').Status__c);
    }
    @IsTest static void scheduler() {
        Test.startTest(); new VehicleOrderBatchScheduler().execute(null); Test.stopTest();
        System.assertEquals(1,[SELECT count() FROM AsyncApexJob WHERE ApexClass.Name='VehicleStockBatch' AND JobType='BatchApex']);
    }
}
