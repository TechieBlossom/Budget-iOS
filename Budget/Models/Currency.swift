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
        Currency(code: "USD", name: "US Dollar", symbol: "$"),
        Currency(code: "EUR", name: "Euro", symbol: "€"),
        Currency(code: "GBP", name: "British Pound", symbol: "£"),
        Currency(code: "JPY", name: "Japanese Yen", symbol: "¥"),
        Currency(code: "INR", name: "Indian Rupee", symbol: "₹"),
        Currency(code: "CAD", name: "Canadian Dollar", symbol: "C$"),
        Currency(code: "AED", name: "UAE Dirham", symbol: "د.إ"),
        Currency(code: "AUD", name: "Australian Dollar", symbol: "A$"),
        Currency(code: "CHF", name: "Swiss Franc", symbol: "CHF"),
        Currency(code: "CNY", name: "Chinese Yuan", symbol: "¥"),
        Currency(code: "SEK", name: "Swedish Krona", symbol: "kr"),
        Currency(code: "NOK", name: "Norwegian Krone", symbol: "kr"),
        Currency(code: "MXN", name: "Mexican Peso", symbol: "$"),
        Currency(code: "SGD", name: "Singapore Dollar", symbol: "S$"),
        Currency(code: "HKD", name: "Hong Kong Dollar", symbol: "HK$"),
        Currency(code: "NZD", name: "New Zealand Dollar", symbol: "NZ$"),
        Currency(code: "KRW", name: "South Korean Won", symbol: "₩"),
        Currency(code: "TRY", name: "Turkish Lira", symbol: "₺"),
        Currency(code: "RUB", name: "Russian Ruble", symbol: "₽"),
        Currency(code: "BRL", name: "Brazilian Real", symbol: "R$"),
        Currency(code: "ZAR", name: "South African Rand", symbol: "R")
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