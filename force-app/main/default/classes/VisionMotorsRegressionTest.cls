@IsTest
private class VisionMotorsRegressionTest {
    @TestSetup static void data() {
        Vehicle_Dealer__c first = new Vehicle_Dealer__c(Name='Regression Chennai', Dealer_Name__c='Regression Chennai', Dealer_Location__c='Chennai');
        Vehicle_Dealer__c second = new Vehicle_Dealer__c(Name='Regression Bengaluru', Dealer_Name__c='Regression Bengaluru', Dealer_Location__c='Bengaluru');
        insert new List<Vehicle_Dealer__c>{first,second};
        insert new Vehicle_Customer__c(Name='Regression Customer', Customer_Name__c='Regression Customer', Address__c='Chennai');
        insert new Vehicle__c(Name='Regression Vehicle', Stock_Quantity__c=2, Status__c='Available', Dealer__c=first.Id);
    }
    private static Vehicle__c vehicle() {
        return [SELECT Id, Stock_Quantity__c, Status__c, Dealer__c FROM Vehicle__c WHERE Name='Regression Vehicle' LIMIT 1];
    }
    private static Vehicle_Order__c order(String status) {
        return new Vehicle_Order__c(Name='Regression Order', Vehicle__c=vehicle().Id, Vehicle_Customer__c=[SELECT Id FROM Vehicle_Customer__c LIMIT 1].Id, Status__c=status);
    }
    @IsTest static void cancellationAndReconfirmation() {
        Vehicle_Order__c o=order('Confirmed'); insert o;
        System.assertEquals(1,vehicle().Stock_Quantity__c);
        o.Status__c='Canceled'; update o;
        System.assertEquals(2,vehicle().Stock_Quantity__c);
        update o;
        System.assertEquals(2,vehicle().Stock_Quantity__c,'Repeated cancellation must restore stock only once');
        o.Status__c='Confirmed'; update o;
        System.assertEquals(1,vehicle().Stock_Quantity__c,'Reconfirmation must reserve one vehicle');
    }
    @IsTest static void customerChangeReassignsDealer() {
        Vehicle_Order__c o=order('Pending'); insert o;
        Id localDealer=[SELECT Id FROM Vehicle_Dealer__c WHERE Dealer_Location__c='Bengaluru' LIMIT 1].Id;
        Vehicle_Customer__c c=new Vehicle_Customer__c(Name='Bengaluru Customer',Customer_Name__c='Bengaluru Customer',Address__c='Bengaluru'); insert c;
        o.Vehicle_Customer__c=c.Id; update o;
        System.assertEquals(localDealer,[SELECT Dealer__c FROM Vehicle_Order__c WHERE Id=:o.Id].Dealer__c);
        System.assertEquals(2,vehicle().Stock_Quantity__c,'Pending updates must not reserve inventory');
    }
    @IsTest static void pendingWaitsForReplenishment() {
        Vehicle_Order__c o=order('Pending'); insert o;
        Vehicle__c v=vehicle(); v.Stock_Quantity__c=0; v.Status__c='Out of Stock'; update v;
        VehicleOrderBatch batch=new VehicleOrderBatch();
        batch.execute(null,new List<Vehicle_Order__c>{o});
        System.assertEquals('Pending',[SELECT Status__c FROM Vehicle_Order__c WHERE Id=:o.Id].Status__c);
        v.Stock_Quantity__c=1; v.Status__c='Available'; update v;
        batch.execute(null,new List<Vehicle_Order__c>{o});
        System.assertEquals('Confirmed',[SELECT Status__c FROM Vehicle_Order__c WHERE Id=:o.Id].Status__c);
        System.assertEquals(0,vehicle().Stock_Quantity__c);
        System.assertEquals('Out of Stock',vehicle().Status__c);
    }
    @IsTest static void inventoryReplenishmentCount() {
        Vehicle__c v=vehicle(); v.Status__c='Out of Stock'; update v;
        VehicleStockBatch batch=new VehicleStockBatch();
        batch.execute(null,new List<Vehicle__c>{v});
        System.assertEquals(1,batch.replenished);
        System.assertEquals('Available',vehicle().Status__c);
        batch.execute(null,new List<Vehicle__c>{vehicle()});
        System.assertEquals(1,batch.replenished,'Available inventory must not be counted twice');
    }
    @IsTest static void nullStockCannotBeConfirmed() {
        Vehicle__c v=vehicle(); v.Stock_Quantity__c=null; update v;
        Database.SaveResult result=Database.insert(order('Confirmed'),false);
        System.assert(!result.isSuccess(),'Missing stock must be treated as unavailable');
        System.assert(result.getErrors()[0].getMessage().contains('out of stock'));
    }
}
