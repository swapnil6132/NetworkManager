//
//  RestService.swift
//  ServiceHandler
//
//  Created by Swapnil Patel on 27/03/25.
//

import Foundation

public class RestService {
    private let baseURL: URL

    public init(baseURL: String) {
        guard let url = URL(string: baseURL) else {
            fatalError("Invalid Base URL")
        }
        self.baseURL = url
    }

    public func performRequest<T: Decodable>(
        endpoint: String,
        method: HttpMethod,
        headers: [String: String]? = nil,
        queryParams: [String: String]? = nil,
        body: Data? = nil,
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        // Construct the full URL with query parameters
        var urlWithParams = baseURL.appendingPathComponent(endpoint)
        if let queryParams = queryParams {
            var urlComponents = URLComponents(url: urlWithParams, resolvingAgainstBaseURL: false)
            urlComponents?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
            if let updatedURL = urlComponents?.url {
                urlWithParams = updatedURL
            }
        }

        // Create the URLRequest
        var request = URLRequest(url: urlWithParams)
        request.httpMethod = method.rawValue

        // Add headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add body for POST/PUT requests
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // Perform the network request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "NoDataError", code: -1, userInfo: nil)))
                return
            }

            // Decode the response
            do {
                let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decodedResponse))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    public func uploadMedia(
        endpoint: String,
        method: String = "POST",
        headers: [String: String]? = nil,
        media: [Media],
        additionalFields: [String: String]? = nil,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        // Construct the full URL
        let urlWithParams = baseURL.appendingPathComponent(endpoint)

        // Create the URLRequest
        var request = URLRequest(url: urlWithParams)
        request.httpMethod = method

        // Add headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let body = createMultipartBody(media: media, additionalFields: additionalFields, boundary: boundary)
        request.httpBody = body

        // Perform the network request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "NoDataError", code: -1, userInfo: nil)))
                return
            }

            completion(.success(data))
        }.resume()
    }

    private func createMultipartBody(
        media: [Media],
        additionalFields: [String: String]?,
        boundary: String
    ) -> Data {
        var body = Data()

        // Add additional fields
        additionalFields?.forEach { key, value in
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Add media files
        for file in media {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}

// Media struct for file uploads
public struct Media {
    let fieldName: String
    let fileName: String
    let mimeType: String
    let data: Data
}

// Extension to append Data
extension Data {
    mutating func append(_ data: Data) {
        self.append(data)
    }
}

public enum HttpMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
