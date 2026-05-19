//
//  API.swift
//  VerkadaKit
//
//  Internal namespace for the per-resource `Endpoints` enums. Keeping
//  them under `API.*` (rather than at the top level of the module)
//  prevents collisions with consumers' own types named `Doors`, `Cameras`,
//  etc. — Verkada itself surfaces those names through the typed model
//  layer (`Door`, `Camera`, `AccessUser`) instead.
//

internal enum API {}
