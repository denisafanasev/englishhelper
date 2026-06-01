//
//  RootViewModel.swift
//  EnglishHelper — Presentation
//
//  MVVM. View models consume USE CASES only (never ports or adapters directly). The App
//  composition root constructs them with concrete use cases, so Presentation stays decoupled
//  from Data and from the App module.
//

import Foundation
import Domain

@MainActor
@Observable
public final class RootViewModel {
    public private(set) var status: String = "Skeleton · running on mocks"
    public private(set) var expressionCount: Int = 0

    private let studyList: any StudyListUseCase

    public init(studyList: any StudyListUseCase) {
        self.studyList = studyList
    }

    public func load() async {
        do {
            expressionCount = try await studyList.list().count
        } catch {
            status = "Failed to load study list"
        }
    }
}
