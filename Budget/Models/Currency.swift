import Foundation

struct Currency: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let name: String
    let symbol: String
    
    init(code: String, name: String, symbol: String) {
        self.code = code
        self.name = name
        self.symbol = symbol
    }
}

extension Currency {
    static let commonCurrencies: [Currency] = [
        Currency(code: "USD", name: "US Dollar", symbol: "USD"),
        Currency(code: "EUR", name: "Euro", symbol: "EUR"),
        Currency(code: "GBP", name: "British Pound", symbol: "GBP"),
        Currency(code: "JPY", name: "Japanese Yen", symbol: "JPY"),
        Currency(code: "INR", name: "Indian Rupee", symbol: "INR"),
        Currency(code: "CAD", name: "Canadian Dollar", symbol: "CAD"),
        Currency(code: "AED", name: "UAE Dirham", symbol: "AED"),
        Currency(code: "AUD", name: "Australian Dollar", symbol: "AUD"),
        Currency(code: "CHF", name: "Swiss Franc", symbol: "CHF"),
        Currency(code: "CNY", name: "Chinese Yuan", symbol: "CNY"),
        Currency(code: "SEK", name: "Swedish Krona", symbol: "SEK"),
        Currency(code: "NOK", name: "Norwegian Krone", symbol: "NOK"),
        Currency(code: "MXN", name: "Mexican Peso", symbol: "MXN"),
        Currency(code: "SGD", name: "Singapore Dollar", symbol: "SGD"),
        Currency(code: "HKD", name: "Hong Kong Dollar", symbol: "HKD"),
        Currency(code: "NZD", name: "New Zealand Dollar", symbol: "NZD"),
        Currency(code: "KRW", name: "South Korean Won", symbol: "KRW"),
        Currency(code: "TRY", name: "Turkish Lira", symbol: "TRY"),
        Currency(code: "RUB", name: "Russian Ruble", symbol: "RUB"),
        Currency(code: "BRL", name: "Brazilian Real", symbol: "BRL"),
        Currency(code: "ZAR", name: "South African Rand", symbol: "ZAR")
    ]
    
    var displayName: String {
        "\(name) (\(code))"
    }
    
    static func search(_ query: String, in currencies: [Currency] = commonCurrencies) -> [Currency] {
        guard !query.isEmpty else { return currencies }
        
        let lowercaseQuery = query.lowercased()
        return currencies.filter {
            $0.name.lowercased().contains(lowercaseQuery) ||
            $0.code.lowercased().contains(lowercaseQuery) ||
            $0.symbol.contains(query)
        }
    }
}