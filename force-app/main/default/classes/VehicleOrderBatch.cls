public without sharing class VehicleOrderBatch implements Database.Batchable<SObject>, Database.Stateful {
    public Integer confirmed = 0;
    public Integer failed = 0;
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Vehicle__c, Vehicle_Customer__c, Status__c
            FROM Vehicle_Order__c WHERE Status__c = 'Pending' ORDER BY CreatedDate, Id]);
    }
    public void execute(Database.BatchableContext bc, List<Vehicle_Order__c> orders) {
        Set<Id> ids = new Set<Id>();
        for (Vehicle_Order__c o : orders) if (o.Vehicle__c != null) ids.add(o.Vehicle__c);
        Map<Id, Decimal> available = new Map<Id, Decimal>();
        for (Vehicle__c v : [SELECT Id, Stock_Quantity__c, Status__c FROM Vehicle__c WHERE Id IN :ids]) {
            available.put(v.Id, v.Status__c == 'Discontinued' || v.Stock_Quantity__c == null ? 0 : v.Stock_Quantity__c);
        }
        List<Vehicle_Order__c> ready = new List<Vehicle_Order__c>();
        for (Vehicle_Order__c o : orders) {
            if (o.Vehicle_Customer__c != null && available.containsKey(o.Vehicle__c) && available.get(o.Vehicle__c) > 0) {
                o.Status__c = 'Confirmed'; ready.add(o);
                available.put(o.Vehicle__c, available.get(o.Vehicle__c) - 1);
            }
        }
        if (!ready.isEmpty()) for (Database.SaveResult result : Database.update(ready, false)) {
            if (result.isSuccess()) confirmed++; else failed++;
        }
    }
    public void finish(Database.BatchableContext bc) {
        if (!Test.isRunningTest() && (confirmed > 0 || failed > 0)) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(UserInfo.getUserId());
            mail.setSaveAsActivity(false);
            mail.setSubject('WhatNext Vision Motors: Order processing summary');
            mail.setPlainTextBody('Confirmed orders: ' + confirmed + '\nOrders requiring review: ' + failed + '\nOrders without available stock remain Pending.');
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
        }
    }
}
