//
// XdnmbAPIClient.swift
// Author: Maru
//

import Foundation

protocol XdnmbAPIClient: Sendable {
    func bootstrap() async
    func forumGroups(userHash: String?) async throws -> [ForumCategory]
    func timelines(userHash: String?) async throws -> [Timeline]
    func notice() async throws -> SiteNotice
    func timelineThreads(id: Int, page: Int, userHash: String?) async throws -> [ForumThread]
    func forumThreads(id: Int, page: Int, userHash: String?) async throws -> [ForumThread]
    func thread(id: Int, page: Int, onlyPO: Bool, userHash: String?) async throws -> ThreadDetail
    func reference(id: Int, userHash: String?) async throws -> Post
    func lastPost(userHash: String) async throws -> LastPost
    func feed(id: String, page: Int, userHash: String?) async throws -> [FeedEntry]
    func addFeed(feedID: String, threadID: Int, userHash: String) async throws -> String
    func deleteFeed(feedID: String, threadID: Int, userHash: String) async throws -> String
    func createThread(
        forumID: Int,
        content: String,
        title: String,
        name: String,
        imageData: Data?,
        imageExtension: String?,
        userHash: String
    ) async throws
    func reply(
        threadID: Int,
        content: String,
        title: String,
        name: String,
        imageData: Data?,
        imageExtension: String?,
        userHash: String
    ) async throws
}
