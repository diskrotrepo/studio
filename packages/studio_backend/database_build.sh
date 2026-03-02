#!/bin/bash

dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/src/database/database.dart lib/src/database/drift_schemas/
dart run drift_dev schema steps lib/src/database/drift_schemas/ lib/src/database/schema_versions.dart