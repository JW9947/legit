// Save this as database.mm

#import <Foundation/Foundation.h>
#include <sqlite3.h> // REAL SQLITE LIBRARY
#include <iostream>
#include <string>
#include <vector>
#include <map>

namespace DatabaseModule {

    class DatabaseExtractor {
    public:
        // REAL DATABASE QUERY FUNCTION
        std::vector<std::map<std::string, std::string>> execute_sqlite_query(const std::string& db_path, const std::string& query, const std::vector<std::string>& columns) {
            std::vector<std::map<std::string, std::string>> results;
            sqlite3 *db;
            sqlite3_stmt *stmt;

            // 1. Open the database file
            if (sqlite3_open(db_path.c_str(), &db) != SQLITE_OK) {
                std::cout << "[DB-ERR] Failed to open database: " << db_path << "\n";
                return results;
            }

            // 2. Prepare the SQL query
            if (sqlite3_prepare_v2(db, query.c_str(), -1, &stmt, NULL) != SQLITE_OK) {
                std::cout << "[DB-ERR] Failed to prepare query.\n";
                sqlite3_close(db);
                return results;
            }

            // 3. Iterate through the results (REAL DATA FROM THE FILE)
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                std::map<std::string, std::string> row;
                for (size_t i = 0; i < columns.size(); ++i) {
                    const unsigned char *text = sqlite3_column_text(stmt, i);
                    if (text != NULL) {
                        row[columns[i]] = std::string(reinterpret_cast<const char*>(text));
                    } else {
                        row[columns[i]] = "<NULL>";
                    }
                }
                results.push_back(row);
            }

            // 4. Clean up
            sqlite3_finalize(stmt);
            sqlite3_close(db);
            return results;
        }

        void extract_imessage() {
            std::cout << "[DB] --- Starting iMessage Extraction ---\n";
            std::string db_path = "/var/mobile/Library/SMS/sms.db";
            
            std::string query = "SELECT message.text, handle.id, message.date FROM message LEFT JOIN handle ON message.handle_id = handle.ROWID";
            std::vector<std::string> columns = {"text", "handle.id", "date"};
            
            // Use the real function
            auto rows = execute_sqlite_query(db_path, query, columns);
            
            if (rows.empty()) {
                std::cout << "[DB] No messages found or database inaccessible.\n";
            } else {
                std::cout << "[DB] Extracted " << rows.size() << " real messages.\n";
                // Print the first message just to prove it works
                std::cout << "[DB] Sample: " << rows[0]["text"] << "\n";
            }
        }
    };
}