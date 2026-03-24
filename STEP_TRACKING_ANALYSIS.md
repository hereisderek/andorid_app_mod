# Analysis: Step Tracking in AIA Vitality (com.aia.gr.rn.nz.v2022.vitality)

This document details how the AIA Vitality application tracks daily steps and how the Xposed module manipulates these values.

## Step Tracking Architecture

The application uses a hybrid approach, combining native Android modules with a React Native frontend. Step tracking is primarily handled by the **Vitality Health Kit** module.

### 1. Google Fit Integration
On Android, the app relies heavily on **Google Fit** for activity data.
- **Module**: `com.vitalityhealthkit.GoogleFitStepCounter`
- **Mechanism**: It uses the Google Fit `HistoryClient` to query data sets (`DataSet`) for specific time ranges (buckets).
- **Data Retrieval**: The app queries for `DataType.TYPE_STEP_COUNT_DELTA` (obfuscated as `com.google.android.gms.fitness.data.DataType.x` in some versions).

### 2. Data Processing Flow
1.  `GoogleFitStepCounter.readFitnessData()` is called to start the sync.
2.  Data points are retrieved from Google Fit.
3.  Each data point is processed by `readDataFromDataPointField`.
4.  The actual insertion into the data object passed back to React Native happens in:
    `private void putValueIntoReadingObject(Map<String, Object> map, DataPoint dataPoint, Field field, String str)`

### 3. Internal Data Structure
The app stores reading data in a `HashMap<String, Object>`.
- **Key for Steps**: `"steps"` (retrieved from `uf.c.j()` which is the obfuscated `com.google.android.gms.fitness.data.Field.getName()`).
- **Value**: String representation of the step count.

## Xposed Manipulation Strategy

The Xposed module targets the `putValueIntoReadingObject` method to intercept and modify the step count before it is returned to the JavaScript layer.

### Hook Implementation
The hook intercepts the `putValueIntoReadingObject` call and performs the following:
1.  Identifies the field being processed by calling `field.j()` (getName).
2.  If the field name is `"steps"`, it retrieves the current value from the `map`.
3.  It applies the user-defined **Step Multiplier** or **Fixed Step Count** from the module's settings.
4.  It updates the `map` with the modified value.

### Settings and Configuration
The Xposed module provides a settings screen (`SettingsActivity`) allowing users to:
-   **Toggle Bypasses**: Enable/Disable security checks.
-   **Enable Step Hook**: Toggle the step manipulation logic.
-   **Step Multiplier**: Set a float value to multiply real steps (e.g., `2.0` for double steps).
-   **Fixed Steps**: Set a static number of steps to report regardless of actual activity.

## Summary of Findings
-   **Sync Source**: Google Fit `HistoryClient`.
-   **Injection Point**: `com.vitalityhealthkit.GoogleFitStepCounter.putValueIntoReadingObject`.
-   **Data Format**: Integer steps stored as Strings in a Map.
-   **Bypass**: Successfully implemented via method hooking in the Xposed module.
