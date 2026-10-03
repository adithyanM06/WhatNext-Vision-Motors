public without sharing class VehicleStockBatch implements Database.Batchable<SObject>, Database.Stateful {
    public Integer replenished = 0;
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Stock_Quantity__c, Status__c FROM Vehicle__c WHERE Status__c != 'Discontinued']);
    }
    public void execute(Database.BatchableContext bc, List<Vehicle__c> vehicles) {
        List<Vehicle__c> changes = new List<Vehicle__c>();
        for (Vehicle__c v : vehicles) {
            String status = v.Stock_Quantity__c != null && v.Stock_Quantity__c > 0 ? 'Available' : 'Out of Stock';
            if (v.Status__c != status) {
                if (v.Status__c == 'Out of Stock' && status == 'Available') replenished++;
                v.Status__c = status; changes.add(v);
            }
        }
        if (!changes.isEmpty()) update changes;
    }
    public void finish(Database.BatchableContext bc) {
        if (!Test.isRunningTest()) {
            if (replenished > 0) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(UserInfo.getUserId()); mail.setSaveAsActivity(false);
                mail.setSubject('WhatNext Vision Motors: Stock replenishment');
                mail.setPlainTextBody(replenished + ' vehicle models are available again. Pending orders will now be processed.');
                Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
            }
            Database.executeBatch(new VehicleOrderBatch(), 50);
        }
    }
}
