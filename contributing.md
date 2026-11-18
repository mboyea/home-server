1. Rules

   - Specificity beats generalization; if provided a specific rule, follow that rule even when a more general rule would conflict with it.

2. Interfaces and Identifiers

   1. Use the proper case for each identifier:

      - `lower-kebab-case` for filenames where possible
      - `camelCase` for variables and functions
      - `PascalCase` for types like classes and enums
      - `lower_snake_case` for any local identifier in shell scripts (variables, functions, types, etc)
      - `UPPER_SNAKE_CASE` for environment variables and true constants

   2. Use explicit types over implicit or dynamic types, except where the type is already written explicitly on the same line;
      ex:

      ```ts
      let value: number = 0
      let valuesFromFunction: number[] = someFunction()
      // no need to declare type
      let valuesFromConstructor = new Array<number>()
      ```

   3. Utilize semantic identifiers ([video reference](https://www.youtube.com/watch?v=-J3wNP6u5YU)):

      - Prefer full words over abbreviations

      - Avoid disinformation and meaningless distinctions;
        ex: `controller`, `manager`

      - Begin with the most general words first, followed by descriptive modifiers;
        for tightly coupled elements, use closely related identifiers;
        if all identifiers were alphabetized in a list, the design of the software should be clear;
        ex:

        ```
        components/
        |- search-button-clear.vue
        |- search-button-run.vue
        |- search-input-query.vue
        |- search-input-exclude-glob.vue
        |- settings-checkbox-terms.vue
        |- settings-checkbox-launch-on-startup.vue
        |- to-do-list.vue
        |- to-do-list-item.vue
        |- to-do-list-item-button.vue
        ```

      - Begin function and method identifiers with a verb, followed by the noun they modify;
        prefer to use [approved Microsoft PowerShell verbs](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands);
        ex:

        ```js
        function GetCustomer() {}
        function RemoveCustomer() {}
        ```

      - Prefix private identifiers with an underscore

      - Prefix boolean identifier nouns with the verb `is`;
        ex:

        ```js
        _isActive = true;
        function GetIsActive() {
          return _isActive
        }
        ```

      - Elements with multiple attributes or arguments should span multiple lines, with one attribute per line where possible;
        ex:

        ```html
        <img
          src="https://vuejs.org/images/logo.png"
          alt="Vue Logo"
        >
        ```

        ```js
        Configure(
          name,
          options = {
            retryCount = 3,
            timeout = 10000
          },
          onComplete = () => {
            console.log('Done')=
            refresh()
          }
        )
        ```

3. Spacing
   - Indent lines using spaces where possible, 2 spaces per indentation level
   - Place opening brackets on the same line as the declaration or control statement

     ```js
     if (_isActive) {
       return
     }
     ```

   - When closing brackets cannot be placed on the same line as opening brackets, place them on their own line, aligned with the start of the declaration or statement
   - When chaining multiple method calls on an object, place each method call on its own line where possible;
     ex:

     ```js
     fullName
       .split(' ')
       .map((word) => word[0].toUpperCase() + word.slice(1))
       .join(' ')
     ```

   - Separate logical sections of code with a single blank line where useful

4. Comments

   1. Given that other instructions are followed, code should be self-explanatory by its types and names

   2. Comments should describe code architecture, warnings, and TODOs;
   never business problems nor code logic

   3. Comments should use a consistent format:

      ```cs
      /* SECTION TITLE */
      // write a clause in the 2nd person perspective describing subsequent actions
      ```

      ```sh
      ### SECTION H1 ###
      # write a clause in the 2nd person perspective describing subsequent actions
      ```

5. Code and Architecture

   1. DRY;
      Don't Repeat Yourself;
      functions, methods, and types should be reused as much as possible

   2. YAGNI (You Aren't Gonna Need It): Don't build for hypothetical futures

   3. KISS (Keep It Simple): Avoid unnecessary complexity

   4. BSR (Boy Scout Rule): Leave code cleaner than you found it

   5. Prefer the REST paradigm for data storage and retrieval
      Representational State Transfer;
      build modular and typical data access protocols

   6. Data structures should only expose data, and have minimal behavior

   7. Objects should hide their data behind abstractions, and expose operations through methods;
      objects should expose as little of their internal structure as possible;
      objects should have few responsibilities according to the Single Responsibility Principle;
      object data should be highly cohesive between functions;
      objects should rely upon minimal coupling with other objects;
      utilize interfaces to bridge a gap between objects

   8. Follow the Law of Demeter;
      only chain method calls when the underlying data structure does not change (such as concurrent operations on a `string`);
      ask objects for the information or action you need in one step, according to a declared interface
      ex:

      ```ts
      interface User {
        getFullName(): string
      }
      
      class Profile {
        constructor(
          private readonly user: User
        ) {}
      
        getDisplayName(): string {
          return this.formatName(this.user.getFullName())
        }
      
        private formatName(fullName: string): string {
          return fullName
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.slice(1))
            .join(' ')
        }
      }
      
      const displayName = profile.getDisplayName()
      ```

   9. Features should be modularized
