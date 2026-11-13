//
//  Copyright (c) 2017. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  Modified by Kiseok (MicroRIBs): RxSwift -> Swift Concurrency migration.
//  Derived from uber/RIBs-iOS.
//
//
//  Dependency.swift
//  MicroRIBs
//
//  Created by Kiseok on 12/20/25.
//

// RxSwift replacement mapping:
// Uber RIBs `Dependency` protocols are kept as-is, but isolated to the main
// actor so dependency resolution matches the framework's main-thread-only model.

/// The base protocol for all dependencies.
@MainActor
public protocol Dependency: AnyObject {}

/// The base protocol for an empty dependency.
@MainActor
public protocol EmptyDependency: Dependency {}
