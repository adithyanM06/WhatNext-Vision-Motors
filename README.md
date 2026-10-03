# WhatNext Vision Motors

Salesforce Developer project for Naan Mudhalvan.

## Overview

A Lightning app for vehicle inventory, dealers, customers, orders, test drives and service requests. Apex validates vehicle availability, assigns dealers by matching the customer location, and reserves inventory when orders are confirmed. Batch Apex processes pending orders and synchronizes stock availability.

## Verification

On 3 October 2026, a fresh Salesforce test run passed all 14 project tests: VisionMotorsTest (9/9) and VisionMotorsRegressionTest (5/5). The stock/order trigger handler reports 100% code coverage (63/63 lines). The demo order is Confirmed and linked to the demo EV, customer and Chennai dealer.

## Components

- Six custom objects and navigation tabs.
- WhatNext Vision Motors Lightning app.
- Auto Assign Dealer and Test Drive Reminder flows.
- VehicleOrderTriggerHandler, VehicleOrderBatch, VehicleOrderBatchScheduler and VehicleStockBatch.
- VisionMotorsTest and VisionMotorsRegressionTest.

## Project resources

[Assigned project guide](https://docs.google.com/document/d/1mGDkv7UBXCAsxvbQbdrWtnLZubPShTbv8yxK7ztFSWg/edit)

## Submission

GitHub link: https://github.com/adithyanM06/WhatNext-Vision-Motors

The demo link and final portal submission are still being prepared. A Salesforce org URL requires authentication and is not a public demo video.
