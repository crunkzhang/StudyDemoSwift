import Foundation

final class BundleConfigFetcher {
    enum FetchError: Error {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
    }
}

extension BundleConfigFetcher {
    func fetch(remoteURL: String, completion: @escaping (Result<UpdateConfig, FetchError>) -> Void) {
        guard let url = URL(string: "\(remoteURL)/update-config.json") else {
            completion(.failure(.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error {
                completion(.failure(.networkError(error)))
                return
            }
            guard let data else {
                completion(.failure(.networkError(
                    NSError(domain: "BundleConfigFetcher", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No data"])
                )))
                return
            }
            do {
                let config = try JSONDecoder().decode(UpdateConfig.self, from: data)
                completion(.success(config))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }
}
