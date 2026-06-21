//
//  PersistenceMigration.swift
//  EnglishHelper — Data (SwiftData)
//
//  Versioned schema + migration plan for the on-disk store. The point is forward safety: when the
//  @Model shape changes, add a new VersionedSchema and a MigrationStage here so the store MIGRATES
//  instead of failing to open — a failed open would otherwise drop the user's saved study list and
//  history. With one version the plan is a no-op, but the scaffolding is in place.
//

import Foundation
import SwiftData

/// v1 — the current shape of `ExpressionModel` + `HistoryModel`.
public enum AppSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    public static var models: [any PersistentModel.Type] { [ExpressionModel.self, HistoryModel.self] }
}

/// Migration plan across schema versions. Append a new `AppSchemaV2` and a `MigrationStage`
/// (lightweight or custom) for every breaking change — never just bump the models.
public enum AppMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
