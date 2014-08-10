# Squeal

Squeal allows [sqlite](http://www.sqlite.org/) databases to be created and accessed with [Swift](https://developer.apple.com/swift/).

## Use the Database class to create and open databases

Databases are accessed through the `Database` class. Squeal supports creating on-disk, temporary, and in-memory 
databases:

```swift
let onDiskDatabase    = Database(path:"contacts.db")
let temporaryDatabase = Database.newTemporaryDatabase()
let inMemoryDatabase  = Database.newInMemoryDatabase()  // alternatively: Database()
```

After creating a `Database` object, it must be opened before use:

```swift
let database = Database()
var error : NSError?
if !database.open(&error) {
    // handle error
}
```

Databases must be closed to free their resources:

```swift
var error : NSError?
if !database.close(&error) {
    // handle error
}
```

Closing a database will attempt to close all outstanding `Statement` objects, but may fail if the database is still
being used elsewhere in your app.

## Prepare Statement objects to execute SQL

Once a database has been opened, SQL commands and queries can be executed through `Statement` objects.

`Statement` objects are created by the `Database.prepareStatement()` method:

```swift
var error : NSError?
let statement = database.prepareStatement("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)",
                                          error:&error)
if statement == nil {
    // handle error
}
```

Preparing a statement compiles and validates the SQL string, but does not execute it. `sqlite` compiles SQL strings into
an internal executable representation. Think of `Statement` objects like mini computer programs.

Once prepared, statements are executed through the `Statement.execute(error:)` or `Statement.query(error:)` methods. `Statement` objects are reusable, and are more efficient when reused. See below for details.

Once a `Statement` is no longer needed, it must be closed to release its resources:

```swift
statement.close()
```

After closing a `Statement`, it is unusable and should be discarded.

### Use `Statement.execute(:error)` to perform updates

Any SQL statement that is not a `SELECT` should use the `execute(error:)` method:

```swift
let executeSucceeded = statement.execute(&error)
```

### Use `Statement.next(:error)` to query the database

`SELECT` statements are special because they return data. To execute a query and iterate through the results, use the
`Statement.next(error:)` method after preparing a statement:

```swift
var error : NSError?
if let statement = database.prepareStatement("SELECT name FROM contacts", error:&error) {
    while true {
        if let hasRow = statement.next(&error) {
            if hasRow {
                // process the row
                var contactName = statement.stringValue("name")
            } else {
                // no more data
            }
        } else {
            // handle error
        }
    }
}
```

As mentioned above, you can think of `Statement` objects as mini programs. The `next(error:)` method is like stepping 
through that program in a debugger. At each step, we call `next(error:)` to advance to the next row. A `Bool?` will be 
returned to indicate whether another row was returned (`true`), all data has been consumed (`false`), or an error 
occured (`nil`).

## Use Squeal from the command line, or a Playground

Accessing Squeal from a playground, or the command-line REPL isn't possible right now. Squeal relies on a custom module.map to access sqlite from Swift, and this isn't supported in the XCode betas (yet?).

Any suggestions for a workaround would be appreciated!

