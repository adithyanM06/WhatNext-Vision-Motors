trigger VehicleOrderTrigger on Vehicle_Order__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) VehicleOrderTriggerHandler.beforeSave(Trigger.new, Trigger.isUpdate ? Trigger.oldMap : null);
    if (Trigger.isAfter) VehicleOrderTriggerHandler.afterSave(Trigger.new, Trigger.isUpdate ? Trigger.oldMap : null);
}
