ALTER TABLE Properties  ADD COLUMN attributes TEXT;
WITH StepGroups AS (
  SELECT
    STEP_ID,
    json_group_array(
      json_object(
        'PsetName', PsetName,
        'PropertyName', PropertyName,
        'PropertyValue', PropertyValue,
        'Unit', Unit
      )
    ) AS attributes_json
  FROM Properties
  GROUP BY STEP_ID
)
UPDATE Properties
SET attributes = (
  SELECT attributes_json
  FROM StepGroups
  WHERE Properties.STEP_ID = StepGroups.STEP_ID and PropertyName = "IFC Class"
);