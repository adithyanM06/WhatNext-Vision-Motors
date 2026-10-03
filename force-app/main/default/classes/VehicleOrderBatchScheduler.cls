global class VehicleOrderBatchScheduler implements Schedulable {
    global void execute(SchedulableContext context) {
        Database.executeBatch(new VehicleStockBatch(), 200);
    }
}
