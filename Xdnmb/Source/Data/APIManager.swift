//
//  APIManager.swift
//  Xdnmb
//
//  Created by Yuno's on 2025/5/7.
//

import Foundation
import AFNetworking

final class XdnmbUrls {
    static let shared = XdnmbUrls()
    
    // MARK: - Constants
    static let xdnmbHost = "www.nmbxd.com"
    private static let cdnPath = "Api/getCdnPath"
    private static let backupApiPath = "Api/backupUrl"
    
    // MARK: - URLs
    private static let originBaseUrl = URL(string: "https://\(xdnmbHost)/")!
    private static let currentBaseUrl = URL(string: "https://www.nmbxd1.com/")!
    private static let currentCdnUrl = URL(string: "https://image.nmb.best/")!
    private static let currentBackupApiUrl = URL(string: "https://api.nmb.best/")!
    static let notice = URL(string: "https://nmb.ovear.info/nmb-notice.json")!
    
    // MARK: - Properties
    private(set) var baseUrl: URL
    private(set) var cdnUrl: URL
    private(set) var backupApiUrl: URL
    var useBackupApi: Bool = false
    
    var apiUrl: URL {
        return useBackupApi ? backupApiUrl : baseUrl
    }
    
    var cdnList: URL {
        return apiUrl.appendingPathComponent(Self.cdnPath)
    }
    
    var backupApiList: URL {
        return apiUrl.appendingPathComponent(Self.backupApiPath)
    }
    
    var forumList: URL {
        return apiUrl.appendingPathComponent("Api/getForumList")
    }
    
    var timelineList: URL {
        return apiUrl.appendingPathComponent("Api/getTimelineList")
    }
    
    var getLastPost: URL {
        return baseUrl.appendingPathComponent("Api/getLastPost")
    }
    
    var postNewThread: URL {
        return baseUrl.appendingPathComponent("Home/Forum/doPostThread.html")
    }
    
    var replyThread: URL {
        return baseUrl.appendingPathComponent("Home/Forum/doReplyThread.html")
    }
    
    var verifyImage: URL {
        return baseUrl.appendingPathComponent("Member/User/Index/verify.html")
    }
    
    var userLogin: URL {
        return baseUrl.appendingPathComponent("Member/User/Index/login.html")
    }
    
    var cookiesList: URL {
        return baseUrl.appendingPathComponent("Member/User/Cookie/index.html")
    }
    
    var getNewCookie: URL {
        return baseUrl.appendingPathComponent("Member/User/Cookie/apply.html")
    }
    
    var registerAccount: URL {
        return baseUrl.appendingPathComponent("Member/User/Index/sendRegister.html")
    }
    
    var resetPassword: URL {
        return baseUrl.appendingPathComponent("Member/User/Index/sendForgotPassword.html")
    }
    
    private init(baseUrl: URL = currentBaseUrl,
                cdnUrl: URL = currentCdnUrl,
                backupApiUrl: URL = currentBackupApiUrl) {
        self.baseUrl = baseUrl
        self.cdnUrl = cdnUrl
        self.backupApiUrl = backupApiUrl
    }
    
    // MARK: - URL Generation Methods
    func forum(forumId: Int, page: Int = 1) -> URL {
        var components = URLComponents(url: apiUrl.appendingPathComponent("Api/showf"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "\(forumId)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        return components.url!
    }
    
    func htmlForum(forumId: Int, page: Int = 1) -> URL {
        var components = URLComponents(url: baseUrl.appendingPathComponent("Forum/showf"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "\(forumId)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        return components.url!
    }
    
    func timeline(timelineId: Int, page: Int = 1) -> URL {
        var components = URLComponents(url: apiUrl.appendingPathComponent("Api/timeline"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "\(timelineId)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        return components.url!
    }
    
    func thread(mainPostId: Int, page: Int = 1) -> URL {
        var components = URLComponents(url: apiUrl.appendingPathComponent("Api/thread"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "\(mainPostId)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        return components.url!
    }
    
    func reference(postId: Int) -> URL {
        var components = URLComponents(url: apiUrl.appendingPathComponent("Api/ref"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "id", value: "\(postId)")]
        return components.url!
    }
    
    func htmlReference(postId: Int) -> URL {
        var components = URLComponents(url: baseUrl.appendingPathComponent("Home/Forum/ref"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "id", value: "\(postId)")]
        return components.url!
    }
    
    func onlyPoThread(mainPostId: Int, page: Int = 1) -> URL {
        var components = URLComponents(url: apiUrl.appendingPathComponent("Api/po"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "\(mainPostId)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        return components.url!
    }
    
    func feed(feedId: String, page: Int = 1) -> URL {
        var components = URLComponents(url: apiUrl.appendingPathComponent("Api/feed"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "uuid", value: feedId),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        return components.url!
    }
    
    func htmlFeed(page: Int = 1) -> URL {
        return baseUrl.appendingPathComponent("Forum/feed/page/\(page).html")
    }
    
    func addFeed(feedId: String, mainPostId: Int) -> URL {
        var components = URLComponents(url: apiUrl.appendingPathComponent("Api/addFeed"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "uuid", value: feedId),
            URLQueryItem(name: "tid", value: "\(mainPostId)")
        ]
        return components.url!
    }
    
    func addHtmlFeed(mainPostId: Int) -> URL {
        return baseUrl.appendingPathComponent("Home/Forum/addFeed/tid/\(mainPostId).html")
    }
    
    func deleteFeed(feedId: String, mainPostId: Int) -> URL {
        var components = URLComponents(url: apiUrl.appendingPathComponent("Api/delFeed"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "uuid", value: feedId),
            URLQueryItem(name: "tid", value: "\(mainPostId)")
        ]
        return components.url!
    }
    
    func deleteHtmlFeed(mainPostId: Int) -> URL {
        return baseUrl.appendingPathComponent("Home/Forum/delFeed/tid/\(mainPostId).html")
    }
    
    func getCookie(cookieId: Int) -> URL {
        return baseUrl.appendingPathComponent("Member/User/Cookie/export/id/\(cookieId).html")
    }
    
    func deleteCookie(cookieId: Int) -> URL {
        return baseUrl.appendingPathComponent("Member/User/Cookie/delete/id/\(cookieId).html")
    }
    
    // MARK: - URL Validation Methods
    func isBaseUrl(_ url: URL) -> Bool {
        return url.host == baseUrl.host
    }
    
    func isBackupApiUrl(_ url: URL) -> Bool {
        return url.host == backupApiUrl.host
    }
    
    // MARK: - Update Methods
    static func update(completion: @escaping (Result<XdnmbUrls, Error>) -> Void) {
        let manager = AFHTTPSessionManager()
        
        // Get base URL
        manager.get(originBaseUrl.absoluteString, parameters: nil, headers: nil, progress: nil, success: { (task, responseObject) in
            guard let httpResponse = task.response as? HTTPURLResponse,
                  let location = httpResponse.allHeaderFields["Location"] as? String,
                  let baseUrl = URL(string: location) else {
                completion(.failure(NSError(domain: "XdnmbUrls", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get base URL"])))
                return
            }
            
            // Get CDN URL
            manager.get(baseUrl.appendingPathComponent(self.cdnPath).absoluteString, parameters: nil, headers: nil, progress: nil, success: { (task, responseObject) in
                guard let cdnData = responseObject as? [[String: Any]],
                      let cdnUrlString = cdnData.first?["url"] as? String,
                      let cdnUrl = URL(string: cdnUrlString) else {
                    completion(.failure(NSError(domain: "XdnmbUrls", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CDN URL"])))
                    return
                }
                
                // Get backup API URL
                manager.get(baseUrl.appendingPathComponent(self.backupApiPath).absoluteString, parameters: nil, headers: nil, progress: nil, success: { (task, responseObject) in
                    guard let backupData = responseObject as? [String],
                          let backupApiUrl = URL(string: backupData.first ?? self.currentBackupApiUrl.absoluteString) else {
                        completion(.failure(NSError(domain: "XdnmbUrls", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get backup API URL"])))
                        return
                    }
                    
                    let urls = XdnmbUrls(baseUrl: baseUrl, cdnUrl: cdnUrl, backupApiUrl: backupApiUrl)
                    urls.useBackupApi = self.shared.useBackupApi
                    completion(.success(urls))
                }, failure: { (task, error) in
                    completion(.failure(error))
                })
            }, failure: { (task, error) in
                completion(.failure(error))
            })
        }, failure: { (task, error) in
            completion(.failure(error))
        })
    }
}

final class APIManager {
    static let shared = APIManager()
    let urls = XdnmbUrls.shared

    private init() {}

    func response<T: Decodable>(_ response: Any, completion: @escaping (Result<T, Error>) -> Void) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: response, options: .fragmentsAllowed)
            let decoded = try JSONDecoder().decode(T.self, from: jsonData)
            completion(.success(decoded))
        } catch {
            completion(.failure(error))
        }
    }

    func responseArray<T: Decodable>(_ response: Any, completion: @escaping (Result<[T], Error>) -> Void) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: response, options: .fragmentsAllowed)
            print("JSON Data: \(String(data: jsonData, encoding: .utf8) ?? "无法转换为字符串")")
            let decoded = try JSONDecoder().decode([T].self, from: jsonData)
            completion(.success(decoded))
        } catch {
            print("Decoding Error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Key not found: \(key.stringValue), context: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch: expected \(type), context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("Value not found: expected \(type), context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("Unknown decoding error")
                }
            }
            completion(.failure(error))
        }
    }
    
    func getForumCategories(completion: @escaping (Result<[ForumCategory], Error>) -> Void) {
        let manager = AFHTTPSessionManager()
        manager.get(urls.forumList.absoluteString, parameters: nil, headers: nil, progress: nil, success: { [weak self] (task, responseObject) in
            self?.responseArray(responseObject as Any, completion: completion)
        }, failure: { (task, error) in
            completion(.failure(error))
        })
    }

    func getTimelineThreadList(completion: @escaping (Result<[ThreadItem], Error>) -> Void) {
        let manager = AFHTTPSessionManager()
        manager.get(urls.timelineList.absoluteString, parameters: nil, headers: nil, progress: nil, success: { [weak self] (task, responseObject) in
            self?.responseArray(responseObject as Any, completion: completion)
        }, failure: { (task, error) in
            completion(.failure(error))
        })
    }
}