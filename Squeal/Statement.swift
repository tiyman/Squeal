import Foundation
#if os(iOS)
    #if arch(i386) || arch(x86_64)
        import sqlite3_ios_simulator
    #else
        import sqlite3_ios
    #endif
#else
import sqlite3_osx
#endif
typealias SQLiteStatementPointer = COpaquePointer

///
/// Enumeration of all SQLite column types.
///
public enum ColumnType : Int {
    case Integer
    case Float
    case Text
    case Blob
    case Null
    
    static func fromSQLiteColumnType(columnType:Int32) -> ColumnType {
        switch columnType {
        case SQLITE_INTEGER:
            return .Integer
        case SQLITE_TEXT:
            return .Text
        case SQLITE_NULL:
            return .Null
        case SQLITE_FLOAT:
            return .Float
        case SQLITE_BLOB:
            return .Blob
        default:
            return .Text
        }
    }
}

///
/// Statements are used to update the database, query data, and read results. Statements are like methods and can accept
/// parameters. This makes it easy to escape SQL values, as well as reuse statements for optimal performance.
///
/// Statements are prepared from a Database object.
///
public class Statement : NSObject {
    
    // We hold a strong reference to the database to ensure it isn't closed before all statements have been finalized.
    private let database:Database
    private let sqliteStatement:SQLiteStatementPointer
    
    init(database:Database, sqliteStatement:SQLiteStatementPointer) {
        self.database = database
        self.sqliteStatement = sqliteStatement
        
        parameterCount = Int(sqlite3_bind_parameter_count(sqliteStatement))
        
        var columnNames = [String]()
        let columnCount = sqlite3_column_count(sqliteStatement)
        for columnIndex in 0..<columnCount {
            let columnName = sqlite3_column_name(sqliteStatement, columnIndex)
            if columnName != nil {
                if let columnNameString = NSString(UTF8String: columnName) {
                    columnNames.append(columnNameString as String)
                    continue
                }
            }
            
            // add an empty string so the column indices stay the same
            columnNames.append("")
        }
        self.columnNames = columnNames
    }
    
    deinit {
        let result = sqlite3_finalize(sqliteStatement)
        if result != SQLITE_OK {
            NSLog("Error closing statement (resultCode: \(result)): \(database.sqliteError.localizedDescription)")
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Parameters
    
    /// The number of parameters accepted by the statement.
    public let parameterCount : Int
    
    /// Clears all parameter values bound to the statement. All parameters will be NULL after this call.
    public func clearParameters() {
        if sqliteStatement != nil {
            sqlite3_clear_bindings(sqliteStatement)
        }
    }
    
    /// :returns: The 1-based index of a named parameter, or `nil` if no parameter is found with the given name.
    public func indexOfParameterNamed(name:String) -> Int? {
        if let cString = name.cStringUsingEncoding(NSUTF8StringEncoding) {
            let index = sqlite3_bind_parameter_index(sqliteStatement, cString)
            if index > 0 {
                return Int(index)
            }
        }
        
        return nil
    }
    
    private func unknownBindParameterError(name:String) -> NSError {
        let localizedDescription = SquealErrorCode.UnknownBindParameter.localizedDescription + ": " + name
        return NSError(domain:  SquealErrorDomain,
                       code:    SquealErrorCode.UnknownBindParameter.rawValue,
                       userInfo:[ NSLocalizedDescriptionKey : localizedDescription ])
        
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  String Parameters
    
    /// Binds a string value to the parameter at the 1-based index.
    ///
    /// :param:     stringValue     The value to bind.
    /// :param:     atIndex         The 1-based index of the parameter.
    ///
    public func bindStringValue(stringValue:String, atIndex index:Int) throws {
        let cString = stringValue.cStringUsingEncoding(NSUTF8StringEncoding)
        
        let resultCode = sqlite3_bind_text(sqliteStatement, Int32(index), cString!, -1, SQUEAL_TRANSIENT)
        if resultCode != SQLITE_OK {
            throw database.sqliteError
        }
    }
    
    /// Binds a string value to a named parameter.
    ///
    /// :param:     stringValue     The value to bind.
    /// :param:     named           The name of the parameter to bind.
    ///
    public func bindStringValue(stringValue:String, named name:String) throws {
        guard let parameterIndex = indexOfParameterNamed(name) else {
            throw unknownBindParameterError(name)
        }
        
        try bindStringValue(stringValue, atIndex: parameterIndex)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Int Parameters
    
    /// Binds an Int value to the parameter at the 1-based index.
    ///
    /// :param:     intValue        The value to bind.
    /// :param:     atIndex         The 1-based index of the parameter.
    ///
    public func bindIntValue(intValue:Int, atIndex index:Int) throws {
        try bindInt64Value(Int64(intValue), atIndex: index)
    }
    
    /// Binds an Int value to a named parameter.
    ///
    /// :param:     intValue        The value to bind.
    /// :param:     named           The name of the parameter to bind.
    ///
    public func bindIntValue(intValue:Int, named name:String) throws {
        try bindInt64Value(Int64(intValue), named: name)
    }
    
    /// Binds an Int64 value to the parameter at the 1-based index.
    ///
    /// :param:     int64Value      The value to bind.
    /// :param:     atIndex         The 1-based index of the parameter.
    ///
    public func bindInt64Value(int64Value:Int64, atIndex index:Int) throws {
        let resultCode = sqlite3_bind_int64(sqliteStatement, Int32(index), int64Value)
        if resultCode != SQLITE_OK {
            throw database.sqliteError
        }
    }
    
    /// Binds an Int64 value to a named parameter.
    ///
    /// :param:     int64Value      The value to bind.
    /// :param:     named           The name of the parameter to bind.
    ///
    public func bindInt64Value(int64Value:Int64, named name:String) throws {
        guard let parameterIndex = indexOfParameterNamed(name) else {
            throw unknownBindParameterError(name)
        }
        
        try bindInt64Value(int64Value, atIndex: parameterIndex)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Double Parameters
    
    
    /// Binds a Double value to the parameter at the 1-based index.
    ///
    /// :param:     doubleValue     The value to bind.
    /// :param:     atIndex         The 1-based index of the parameter.
    ///
    public func bindDoubleValue(doubleValue:Double, atIndex index:Int) throws {
        let resultCode = sqlite3_bind_double(sqliteStatement, Int32(index), doubleValue)
        if resultCode != SQLITE_OK {
            throw database.sqliteError
        }
    }

    /// Binds a Double value to a named parameter.
    ///
    /// :param:     doubleValue     The value to bind.
    /// :param:     named           The name of the parameter to bind.
    ///
    public func bindDoubleValue(doubleValue:Double, named name:String) throws {
        guard let parameterIndex = indexOfParameterNamed(name) else {
            throw unknownBindParameterError(name)
        }
        
        try bindDoubleValue(doubleValue, atIndex: parameterIndex)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Bool Parameters
    
    /// Binds a Bool value to the parameter at the 1-based index.
    ///
    /// :param:     boolValue       The value to bind.
    /// :param:     atIndex         The 1-based index of the parameter.
    ///
    public func bindBoolValue(boolValue:Bool, atIndex index:Int) throws {
        let resultCode = sqlite3_bind_int(sqliteStatement, Int32(index), Int32(boolValue ? 1 : 0))
        if resultCode != SQLITE_OK {
            throw database.sqliteError
        }
    }
    
    /// Binds a Bool value to a named parameter.
    ///
    /// :param:     boolValue       The value to bind.
    /// :param:     named           The name of the parameter to bind.
    ///
    public func bindBoolValue(boolValue:Bool, named name:String) throws {
        guard let parameterIndex = indexOfParameterNamed(name) else {
            throw unknownBindParameterError(name)
        }
        
        try bindBoolValue(boolValue, atIndex: parameterIndex)
    }
    
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  BLOB Parameters
    
    /// Binds an NSData value to the parameter at the 1-based index.
    ///
    /// :param:     blobValue       The value to bind.
    /// :param:     atIndex         The 1-based index of the parameter.
    ///
    public func bindBlobValue(blobValue:NSData, atIndex index:Int) throws {
        var resultCode: Int32
        if blobValue.bytes != nil {
            resultCode = sqlite3_bind_blob(sqliteStatement, Int32(index), blobValue.bytes, Int32(blobValue.length), SQUEAL_TRANSIENT)
        } else {
            resultCode = sqlite3_bind_zeroblob(sqliteStatement, Int32(index), 0);
        }
        
        if resultCode != SQLITE_OK {
            throw database.sqliteError
        }
    }
    
    /// Binds a BLOB value to a named parameter.
    ///
    /// :param:     blobValue       The value to bind.
    /// :param:     named           The name of the parameter to bind.
    ///
    public func bindBlobValue(blobValue:NSData, named name:String) throws {
        guard let parameterIndex = indexOfParameterNamed(name) else {
            throw unknownBindParameterError(name)
        }
        
        try bindBlobValue(blobValue, atIndex: parameterIndex)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Null Parameters
    
    /// Binds a NULL value to the parameter at the 1-based index.
    ///
    /// :param:     atIndex         The 1-based index of the parameter.
    ///
    public func bindNullParameter(atIndex index:Int) throws {
        let resultCode = sqlite3_bind_null(sqliteStatement, Int32(index))
        if resultCode != SQLITE_OK {
            throw database.sqliteError
        }
    }

    /// Binds a NULL value to a named parameter.
    ///
    /// :param:     name           The name of the parameter to bind.
    ///
    public func bindNullParameter(name:String) throws {
        guard let parameterIndex = indexOfParameterNamed(name) else {
            throw unknownBindParameterError(name)
        }
        
        try bindNullParameter(atIndex:parameterIndex)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Execute
    
    /// Advances to the next row of results. Statements begin before the first row of data, and iterate through the
    /// results through this method.
    ///
    /// For statements that return no results (e.g. anything other than a `SELECT`), use the `execute()` method.
    ///
    /// :returns:   `true` if a new result is available, `false` if the end of the result set is reached
    ///
    public func next() throws -> Bool {
        switch sqlite3_step(sqliteStatement) {
        case SQLITE_DONE:
            // no more steps
            return false
        case SQLITE_ROW:
            // more rows to process
            return true
        default:
            throw database.sqliteError
        }
    }
    
    /// Executes the statement, optionally calling a block after each step.
    ///
    /// :param:     block  A block to call after each execution step.
    ///
    public func execute(@noescape block:(Statement throws -> Void) = { _ in }) throws {
        while try next() {
            try block(self)
        }
    }
    
    /// Resets the statement so it can be executed again. Paramters are NOT cleared. To clear them call
    /// `clearParameters()` after this method.
    ///
    public func reset() throws {
        let resultCode = sqlite3_reset(sqliteStatement)
        if resultCode != SQLITE_OK {
            throw errorFromSQLiteErrorCode(resultCode, message: "Failed to reset statement (resultCode: \(resultCode))")
        }
    }
    
    public func selectNextRow<T>(@noescape block:Statement->T) throws -> T? {
        guard try next() else {
            return nil
        }
        
        return block(self)
    }
    
    public func selectRows<T>(@noescape block:Statement->T) throws -> [T] {
        var results = [T]()
        while try next() {
            let value = block(self)
            results.append(value)
        }
        return results
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Columns
    
    /// The names of each column selected by this statement, or an empty array if the statement is not a SELECT.
    public let columnNames : [String]
    
    /// The number of columns in each row selected by this statement.
    public var columnCount : Int {
        if sqliteStatement == nil {
            return 0
        }
        
        return columnNames.count
    }
    
    /// Looks up the index of a column from its name.
    ///
    /// :param:     columnName  The name of the column to search for.
    /// :returns:   The index of the column, or nil if it wasn't found.
    ///
    public func indexOfColumnNamed(columnName:String) -> Int? {
        return columnNames.indexOf(columnName)
    }
    
    public func nameOfColumnAtIndex(columnIndex:Int) -> String {
        return columnNames[columnIndex]
    }
    
    /// Gets the name of the column at an index.
    ///
    /// :param:     columnIndex The index of a column
    /// :returns:   The name of the column at the index
    ///
    public func columnNameAtIndex(columnIndex:Int) -> String {
        return columnNames[columnIndex]
    }
    
    /// Returns the type of the column at a given index.
    ///
    /// :param:     columnIndex The index of a column
    /// :returns:   The SQLite type of the column
    ///
    public func typeOfColumnAtIndex(columnIndex:Int) -> ColumnType {
        let columnType = sqlite3_column_type(sqliteStatement, Int32(columnIndex))
        return ColumnType.fromSQLiteColumnType(columnType)
    }
    
    /// Returns the type of the column with the given name.
    ///
    /// :param:     columnName The name of a column.
    /// :returns:   The SQLite type of the column.
    ///
    public func typeOfColumnNamed(columnName:String) -> ColumnType {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return typeOfColumnAtIndex(columnIndex)
        } else {
            fatalError("Column named '\(columnName)' not found")
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK: Current Row
    
    /// All values of the current row, as a Dictionary. Only non-nil values are included in the Dictionary. This is so
    /// `currentRow["id"]` returns a `Bindable?` value, instead of `Bindable??`.
    ///
    public var dictionaryValue: [String:Bindable] {
        var currentRow = [String:Bindable]()
        for columnIndex in 0..<(columnCount) {
            let columnName = nameOfColumnAtIndex(columnIndex)
            currentRow[columnName] = valueAtIndex(columnIndex)
        }
        return currentRow
    }
    
    /// All values of the current row in an array.
    public var values: [Bindable?] {
        var currentRowValues = [Bindable?]()
        for columnIndex in 0..<(columnCount) {
            currentRowValues.append(valueAtIndex(columnIndex))
        }
        return currentRowValues
    }

    /// Returns the value of a column by name.
    public func valueOf(columnName:String) -> Bindable? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return valueAtIndex(columnIndex)
        } else {
            fatalError("Column named '\(columnName)' not found")
        }
    }
    
    public subscript(columnName:String) -> Bindable? {
        return valueOf(columnName)
    }
    
    /// Returns the value of a column based on its index
    public func valueAtIndex(columnIndex:Int) -> Bindable? {
        switch typeOfColumnAtIndex(columnIndex) {
        case .Integer:
            return int64ValueAtIndex(columnIndex)
        case .Text:
            return stringValueAtIndex(columnIndex)
        case .Float:
            return doubleValueAtIndex(columnIndex)
        case .Blob:
            return blobValueAtIndex(columnIndex)
        case .Null:
            return nil
        }
    }
    
    public subscript(columnIndex:Int) -> Bindable? {
        return valueAtIndex(columnIndex)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Integer
    
    /// Reads the value of a named column in the current row, as an Int.
    ///
    /// :param:     columnName The name of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func intValue(columnName:String) -> Int? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return intValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }

    /// Reads the value of a column in the current row, as an Int.
    ///
    /// :param:     columnIndex The 0-based index of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func intValueAtIndex(columnIndex:Int) -> Int? {
        if sqliteStatement == nil {
            return nil
        }
        
        if sqlite3_column_type(sqliteStatement, Int32(columnIndex)) == SQLITE_NULL {
            return nil
        }
        
        return Int(sqlite3_column_int64(sqliteStatement, Int32(columnIndex)))
    }
    
    public func selectNextInt() throws -> Int? {
        guard try next() else {
            return nil
        }
        
        return intValueAtIndex(0)
    }

    /// Reads the value of a named column in the current row, as a 64-bit integer.
    ///
    /// :param:     columnName The name of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func int64Value(columnName:String) -> Int64? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return int64ValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
    /// Reads the value of a column in the current row, as a 64-bit integer.
    ///
    /// :param:     columnIndex The 0-based index of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func int64ValueAtIndex(columnIndex:Int) -> Int64? {
        if sqliteStatement == nil {
            return nil
        }
        
        if sqlite3_column_type(sqliteStatement, Int32(columnIndex)) == SQLITE_NULL {
            return nil
        }
        
        return sqlite3_column_int64(sqliteStatement, Int32(columnIndex))
    }
    
    public func selectNextInt64() throws -> Int64? {
        guard try next() else {
            return nil
        }
        
        return int64ValueAtIndex(0)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Real

    /// Alias for doubleValue(columnName)
    public func realValue(columnName:String) -> Double? {
        return doubleValue(columnName)
    }

    /// Alias for realValueAtIndex(columnIndex)
    public func realValueAtIndex(columnIndex:Int) -> Double? {
        return doubleValueAtIndex(columnIndex)
    }

    /// Reads the value of a named column in the current row, as a Double
    ///
    /// :param:     columnName The name of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func doubleValue(columnName:String) -> Double? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return realValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }

    /// Reads the value of a column in the current row, as a Double.
    ///
    /// :param:     columnIndex The 0-based index of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func doubleValueAtIndex(columnIndex:Int) -> Double? {
        if sqliteStatement == nil {
            return nil
        }
        
        if sqlite3_column_type(sqliteStatement, Int32(columnIndex)) == SQLITE_NULL {
            return nil
        }

        return sqlite3_column_double(sqliteStatement, Int32(columnIndex))
    }
    
    public func selectNextDouble() throws -> Double? {
        guard try next() else {
            return nil
        }
        return doubleValueAtIndex(0)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  String
    
    /// Reads the value of a named column in the current row, as a String
    ///
    /// :param:     columnName The name of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func stringValue(columnName:String) -> String? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return stringValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
    /// Reads the value of a column in the current row, as a String.
    ///
    /// :param:     columnIndex The 0-based index of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func stringValueAtIndex(columnIndex:Int) -> String? {
        if sqliteStatement == nil {
            return nil
        }
        
        let columnText = sqlite3_column_text(sqliteStatement, Int32(columnIndex))
        if columnText == nil {
            return nil
        }
        
        let columnTextI = UnsafePointer<Int8>(columnText)
        return NSString(UTF8String:columnTextI) as String?
    }
    
    public func selectNextString() throws -> String? {
        guard try next() else {
            return nil
        }
        
        return stringValueAtIndex(0)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Boolean
    
    /// Reads the value of a named column in the current row, as a Bool
    ///
    /// :param:     columnName The name of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func boolValue(columnName:String) -> Bool? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return boolValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
    /// Reads the value of a column in the current row, as a Bool.
    ///
    /// :param:     columnIndex The 0-based index of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func boolValueAtIndex(columnIndex:Int) -> Bool? {
        if let intValue = intValueAtIndex(columnIndex) {
            return intValue != 0
        } else {
            return nil
        }
    }
    
    public func selectNextBool() throws -> Bool? {
        guard try next() else {
            return nil
        }
        
        return boolValueAtIndex(0)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK: BLOB Parameters

    public func blobValue(columnName:String) -> NSData? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return blobValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
    public func blobValueAtIndex(columnIndex:Int) -> NSData? {
        if sqliteStatement == nil {
            return nil
        }
        
        // sqlite3_column_blob returns NULL for zero-length blobs. This means its not possible to detect NULL BLOB
        // columns except by type.
        let columnType = sqlite3_column_type(sqliteStatement, Int32(columnIndex))
        if columnType == SQLITE_NULL {
            return nil
        }
        
        let columnBlob = sqlite3_column_blob(sqliteStatement, Int32(columnIndex))
        if columnBlob == nil {
            return NSData()
        }
        
        let columnBytes = sqlite3_column_bytes(sqliteStatement, Int32(columnIndex))
        return NSData(bytes: columnBlob, length: Int(columnBytes))
    }
    
    public func selectNextBlob() throws -> NSData? {
        guard try next() else {
            return nil
        }
        
        return blobValueAtIndex(0)
    }
    
}

// =================================================================================================
// MARK:- SequenceType

public class StepSequence : SequenceType {
    
    private let statement: Statement
    
    init(statement:Statement) {
        self.statement = statement
    }
    
    public func generate() -> StepGenerator {
        return StepGenerator(statement:statement)
    }
    
}

public struct StepGenerator : GeneratorType {
    
    private let statement: Statement
    private var error:NSError?
    private var isComplete: Bool = false
    
    private init(statement:Statement) {
        self.statement = statement
    }
    
    public mutating func next() -> (Statement,NSError?)? {
        if isComplete {
            return nil
        }
        
        let hasNext:Bool
        do {
            hasNext = try statement.next()
        } catch let error as NSError {
            isComplete = true
            return (statement, error)
        }
        
        if !hasNext {
            isComplete = true
            return nil
        }
        
        return (statement, nil)
    }
}