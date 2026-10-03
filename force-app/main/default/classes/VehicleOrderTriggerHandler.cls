public without sharing class VehicleOrderTriggerHandler {
    private static Boolean reserves(Vehicle_Order__c o) {
        return o != null && (o.Status__c == 'Confirmed' || o.Status__c == 'Delivered');
    }
    public static void beforeSave(List<Vehicle_Order__c> orders, Map<Id, Vehicle_Order__c> oldMap) {
        Set<Id> ids = new Set<Id>();
        Set<Id> customerIds = new Set<Id>();
        for (Vehicle_Order__c o : orders) {
            if (o.Vehicle__c != null) ids.add(o.Vehicle__c);
            if (o.Vehicle_Customer__c != null) customerIds.add(o.Vehicle_Customer__c);
        }
        Map<Id, Vehicle__c> vehicles = new Map<Id, Vehicle__c>([
            SELECT Id, Stock_Quantity__c, Status__c, Dealer__c FROM Vehicle__c WHERE Id IN :ids FOR UPDATE
        ]);
        Map<Id, Vehicle_Customer__c> customers = new Map<Id, Vehicle_Customer__c>([
            SELECT Id, Address__c FROM Vehicle_Customer__c WHERE Id IN :customerIds
        ]);
        Set<String> locations = new Set<String>();
        for (Vehicle_Customer__c c : customers.values()) {
            if (!String.isBlank(c.Address__c)) locations.add(c.Address__c.trim());
        }
        Map<String, Id> dealers = new Map<String, Id>();
        for (Vehicle_Dealer__c d : [SELECT Id, Dealer_Location__c FROM Vehicle_Dealer__c
                                  WHERE Dealer_Location__c IN :locations ORDER BY Dealer_Code__c, Id]) {
            String key = d.Dealer_Location__c.trim().toLowerCase();
            if (!dealers.containsKey(key)) dealers.put(key, d.Id);
        }
        Map<Id, Decimal> requested = new Map<Id, Decimal>();
        for (Vehicle_Order__c o : orders) {
            Vehicle_Order__c prior = oldMap == null ? null : oldMap.get(o.Id);
            if (String.isBlank(o.Status__c)) o.Status__c = 'Pending';
            if (o.Order_Date__c == null) o.Order_Date__c = Date.today();
            if (o.Vehicle__c == null || o.Vehicle_Customer__c == null) {
                o.addError('Select a vehicle and a customer before placing an order.');
                continue;
            }
            Vehicle__c v = vehicles.get(o.Vehicle__c);
            if (v == null) continue;
            if (reserves(prior) && prior.Vehicle__c != o.Vehicle__c) {
                o.addError('Cancel the existing order before changing its vehicle.');
                continue;
            }
            Boolean newlyReserved = reserves(o) && !reserves(prior);
            Boolean newActive = prior == null && o.Status__c != 'Canceled';
            if ((newlyReserved || newActive) && v.Status__c == 'Discontinued') {
                o.addError('This vehicle is discontinued. Order cannot be placed.');
                continue;
            }
            Decimal stock = v.Stock_Quantity__c == null ? 0 : v.Stock_Quantity__c;
            Decimal demand = requested.containsKey(v.Id) ? requested.get(v.Id) : 0;
            if ((newActive && stock <= 0) || (newlyReserved && stock <= demand)) {
                o.addError('This vehicle is out of stock. Order cannot be placed or confirmed.');
                continue;
            }
            if (newlyReserved) requested.put(v.Id, demand + 1);
            if (o.Dealer__c == null || (prior != null && prior.Vehicle_Customer__c != o.Vehicle_Customer__c)) {
                Vehicle_Customer__c c = customers.get(o.Vehicle_Customer__c);
                String key = c == null || String.isBlank(c.Address__c) ? null : c.Address__c.trim().toLowerCase();
                o.Dealer__c = dealers.containsKey(key) ? dealers.get(key) : v.Dealer__c;
            }
        }
    }
    public static void afterSave(List<Vehicle_Order__c> orders, Map<Id, Vehicle_Order__c> oldMap) {
        Map<Id, Decimal> changes = new Map<Id, Decimal>();
        for (Vehicle_Order__c o : orders) {
            Vehicle_Order__c prior = oldMap == null ? null : oldMap.get(o.Id);
            if (reserves(o) && !reserves(prior)) addChange(changes, o.Vehicle__c, -1);
            if (!reserves(o) && reserves(prior)) addChange(changes, prior.Vehicle__c, 1);
        }
        if (changes.isEmpty()) return;
        List<Vehicle__c> updates = [SELECT Id, Stock_Quantity__c, Status__c FROM Vehicle__c
                                  WHERE Id IN :changes.keySet() FOR UPDATE];
        for (Vehicle__c v : updates) {
            v.Stock_Quantity__c = (v.Stock_Quantity__c == null ? 0 : v.Stock_Quantity__c) + changes.get(v.Id);
            if (v.Status__c != 'Discontinued') v.Status__c = v.Stock_Quantity__c > 0 ? 'Available' : 'Out of Stock';
        }
        update updates;
    }
    private static void addChange(Map<Id, Decimal> changes, Id vehicleId, Decimal amount) {
        if (vehicleId != null) changes.put(vehicleId, (changes.containsKey(vehicleId) ? changes.get(vehicleId) : 0) + amount);
    }
}
