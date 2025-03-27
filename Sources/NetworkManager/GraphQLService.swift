//
//  GraphQLService.swift
//  ServiceHandler
//
//  Created by Swapnil Patel on 27/03/25.
//

import Foundation

// Define a struct for the GraphQL request
struct GraphQLRequest: Encodable {
    let query: String
    let variables: [String: AnyEncodable]?
}

// Helper struct to encode variables of any type
struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        self.encodeClosure = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

// Define a struct for the GraphQL response
struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

// Define a struct for GraphQL errors
struct GraphQLError: Decodable {
    let message: String
}

// Service handler class
class GraphQLService {
    private let endpointURL: URL

    init(endpoint: String) {
        guard let url = URL(string: endpoint) else {
            fatalError("Invalid URL")
        }
        self.endpointURL = url
    }

    func performQuery<T: Decodable>(
        query: String,
        variables: [String: AnyEncodable]? = nil,
        responseType: T.Type,
        method: String = "POST", // Default to POST
        headers: [String: String]? = nil,
        queryParams: [String: String]? = nil,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        // Add query parameters to the URL if provided
        var urlWithParams = endpointURL
        if let queryParams = queryParams {
            var urlComponents = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
            urlComponents?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
            if let updatedURL = urlComponents?.url {
                urlWithParams = updatedURL
            }
        }

        // Create the URLRequest
        var request = URLRequest(url: urlWithParams)
        request.httpMethod = method

        // Add headers if provided
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add body for POST requests
        if method == "POST" {
            let requestBody = GraphQLRequest(query: query, variables: variables)
            guard let jsonData = try? JSONEncoder().encode(requestBody) else {
                completion(.failure(NSError(domain: "EncodingError", code: -1, userInfo: nil)))
                return
            }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
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
                let decodedResponse = try JSONDecoder().decode(GraphQLResponse<T>.self, from: data)
                if let errors = decodedResponse.errors, !errors.isEmpty {
                    let errorMessages = errors.map { $0.message }.joined(separator: ", ")
                    completion(.failure(NSError(domain: "GraphQLError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessages])))
                } else if let data = decodedResponse.data {
                    completion(.success(data))
                } else {
                    completion(.failure(NSError(domain: "UnknownError", code: -1, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
