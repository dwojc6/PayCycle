import Foundation
import Observation

/// Persists per-category budget amounts locally using UserDefaults.
@MainActor
@Observable
final class BudgetStore {
    private let defaults = UserDefaults.standard
    private let key = "paycycle.categoryBudgets"
    private let periodKey = "paycycle.periodCategoryBudgets"
    private let futureOverrideKey = "paycycle.futureCategoryBudgetOverrides"
    private let expectedPaycheckKey = "paycycle.expectedPaycheck"
    private let hiddenKey = "paycycle.hiddenCategoryIds"

    private(set) var budgets: [Int: Decimal] = [:]
    private(set) var periodBudgets: [String: [Int: Decimal]] = [:]
    private(set) var futureBudgetOverrides: [Int: [BudgetFutureOverride]] = [:]
    private(set) var hiddenCategoryIds: Set<Int> = []
    var expectedPaycheck: Decimal = 4_600 {
        didSet { saveExpectedPaycheck() }
    }

    init() {
        load()
    }

    func budget(for categoryId: Int) -> Decimal? {
        budgets[categoryId]
    }

    func budget(for categoryId: Int, periodId: String?, defaultBudget: Decimal?) -> Decimal? {
        budget(for: categoryId, periodId: periodId, periodStartDate: nil, defaultBudget: defaultBudget)
    }

    func budget(for categoryId: Int, periodId: String?, periodStartDate: Date?, defaultBudget: Decimal?) -> Decimal? {
        if let periodId, let periodBudget = periodBudgets[periodId]?[categoryId] {
            return periodBudget
        }

        if let periodStartDate,
           let override = futureBudgetOverrides[categoryId]?.last(where: { $0.startDate <= periodStartDate }) {
            return override.amount
        }

        return defaultBudget ?? budgets[categoryId]
    }

    func setBudget(_ amount: Decimal, for categoryId: Int) {
        budgets[categoryId] = amount
        save()
    }

    func setBudget(_ amount: Decimal, for categoryId: Int, periodId: String?, applyToFuture: Bool) {
        setBudget(amount, for: categoryId, periodId: periodId, effectiveDate: nil, applyToFuture: applyToFuture)
    }

    func setBudget(_ amount: Decimal, for categoryId: Int, periodId: String?, effectiveDate: Date?, applyToFuture: Bool) {
        if applyToFuture || periodId == nil {
            if let effectiveDate {
                var overrides = futureBudgetOverrides[categoryId] ?? []
                overrides.removeAll { Calendar.current.isDate($0.startDate, inSameDayAs: effectiveDate) }
                overrides.append(BudgetFutureOverride(startDate: effectiveDate, amount: amount))
                futureBudgetOverrides[categoryId] = overrides.sorted { $0.startDate < $1.startDate }
            } else {
                budgets[categoryId] = amount
            }
        } else if let periodId {
            periodBudgets[periodId, default: [:]][categoryId] = amount
        }
        save()
    }

    func isHidden(_ categoryId: Int) -> Bool {
        hiddenCategoryIds.contains(categoryId)
    }

    func setHidden(_ hidden: Bool, for categoryId: Int) {
        if hidden {
            hiddenCategoryIds.insert(categoryId)
        } else {
            hiddenCategoryIds.remove(categoryId)
        }
        save()
    }

    func removeBudget(for categoryId: Int) {
        budgets.removeValue(forKey: categoryId)
        save()
    }

    func removeBudget(for categoryId: Int, periodId: String?, applyToFuture: Bool) {
        removeBudget(for: categoryId, periodId: periodId, effectiveDate: nil, applyToFuture: applyToFuture)
    }

    func removeBudget(for categoryId: Int, periodId: String?, effectiveDate: Date?, applyToFuture: Bool) {
        if applyToFuture || periodId == nil {
            if let effectiveDate {
                futureBudgetOverrides[categoryId]?.removeAll { $0.startDate >= effectiveDate }
                if futureBudgetOverrides[categoryId]?.isEmpty == true {
                    futureBudgetOverrides.removeValue(forKey: categoryId)
                }
            } else {
                budgets.removeValue(forKey: categoryId)
            }
        } else if let periodId {
            periodBudgets[periodId]?.removeValue(forKey: categoryId)
            if periodBudgets[periodId]?.isEmpty == true {
                periodBudgets.removeValue(forKey: periodId)
            }
        }
        save()
    }

    private func load() {
        if let dict = defaults.dictionary(forKey: key) {
            budgets = dict.compactMapValues { val in
                if let str = val as? String { return Decimal(string: str) }
                if let num = val as? Double { return Decimal(num) }
                return nil
            }.compactMapKeys { Int($0) }
        }

        if let dict = defaults.dictionary(forKey: periodKey) as? [String: [String: String]] {
            periodBudgets = dict.mapValues { categoryDict in
                categoryDict.compactMapValues { Decimal(string: $0) }
                    .compactMapKeys { Int($0) }
            }
        }

        if let data = defaults.data(forKey: futureOverrideKey),
           let decoded = try? JSONDecoder().decode([Int: [BudgetFutureOverride]].self, from: data) {
            futureBudgetOverrides = decoded.mapValues { $0.sorted { $0.startDate < $1.startDate } }
        }

        if let paycheckString = defaults.string(forKey: expectedPaycheckKey),
           let paycheck = Decimal(string: paycheckString) {
            expectedPaycheck = paycheck
        }

        if let arr = defaults.array(forKey: hiddenKey) as? [Int] {
            hiddenCategoryIds = Set(arr)
        }
    }

    private func save() {
        let dict = Dictionary(uniqueKeysWithValues: budgets.map { (String($0.key), "\($0.value)") })
        defaults.set(dict, forKey: key)

        let periodDict = periodBudgets.mapValues { categoryDict in
            Dictionary(uniqueKeysWithValues: categoryDict.map { (String($0.key), "\($0.value)") })
        }
        defaults.set(periodDict, forKey: periodKey)

        if let data = try? JSONEncoder().encode(futureBudgetOverrides) {
            defaults.set(data, forKey: futureOverrideKey)
        }

        defaults.set(Array(hiddenCategoryIds), forKey: hiddenKey)
    }

    private func saveExpectedPaycheck() {
        defaults.set("\(expectedPaycheck)", forKey: expectedPaycheckKey)
    }
}

struct BudgetFutureOverride: Codable, Hashable {
    let startDate: Date
    let amount: Decimal
}

private extension Dictionary {
    func compactMapKeys<T: Hashable>(_ transform: (Key) -> T?) -> [T: Value] {
        var result: [T: Value] = [:]
        for (k, v) in self {
            if let newKey = transform(k) { result[newKey] = v }
        }
        return result
    }
}
