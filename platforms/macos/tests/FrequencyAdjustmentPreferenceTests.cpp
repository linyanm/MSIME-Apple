#include "PublicSessionTestOptions.h"
#include "../src/FrequencyAdjustmentPreference.h"
#include "../../../vendor/MetasequoiaImeEngine/user_dictionary/user_dictionary_journal.h"

#include <sqlite3.h>

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <stdexcept>
#include <string>
#include <vector>

namespace
{
void Require(bool condition, const char *message)
{
    if (!condition)
        throw std::runtime_error(message);
}

std::size_t IndexOf(const std::vector<WordItem> &candidates, const std::string &word)
{
    const auto found =
        std::find_if(candidates.begin(), candidates.end(), [&](const WordItem &item) { return item.word == word; });
    return found == candidates.end() ? candidates.size() : static_cast<std::size_t>(found - candidates.begin());
}

void SeedFrequencyFixture(const std::filesystem::path &database_path)
{
    sqlite3 *database = nullptr;
    Require(sqlite3_open(database_path.c_str(), &database) == SQLITE_OK, "Cannot open frequency fixture.");
    Require(sqlite3_exec(database,
                         "DROP TABLE IF EXISTS tbl_1_n;"
                         "CREATE TABLE tbl_1_n(key TEXT,jp TEXT,value TEXT,weight INTEGER);"
                         "INSERT INTO tbl_1_n VALUES('ni','n','甲',100);"
                         "INSERT INTO tbl_1_n VALUES('ni','n','乙',90);"
                         "INSERT INTO tbl_1_n VALUES('ni','n','丙',80);"
                         "INSERT INTO tbl_1_n VALUES('ni','n','丁',70);"
                         "INSERT INTO tbl_1_n VALUES('ni','n','戊',60);"
                         "INSERT INTO tbl_1_n VALUES('ni','n','己',50);",
                         nullptr, nullptr, nullptr) == SQLITE_OK,
            "Cannot populate frequency fixture.");
    sqlite3_close(database);
}

void TypeNi(metasequoia::Session &session)
{
    Require(session.character('n').handled && session.character('i').handled,
            "Frequency fixture did not start a composition.");
}

int RunTest()
{
    using metasequoia::FrequencyAdjustmentMode;
    using metasequoia::mac::EngineFrequencyOptions;
    using metasequoia::mac::NormalizeFrequencyAdjustmentCount;
    using metasequoia::mac::NormalizeFrequencyAdjustmentMode;

    Require(std::string(NormalizeFrequencyAdjustmentMode(nullptr)) == "promote", "Missing mode did not default.");
    Require(std::string(NormalizeFrequencyAdjustmentMode("nope")) == "promote", "Unknown mode did not default.");
    Require(std::string(NormalizeFrequencyAdjustmentMode("pin")) == "pin", "Pin mode was not preserved.");
    Require(NormalizeFrequencyAdjustmentCount(0) == 1 && NormalizeFrequencyAdjustmentCount(7) == 1 &&
                NormalizeFrequencyAdjustmentCount(3) == 3,
            "Count normalization did not keep 1–6.");
    Require(EngineFrequencyOptions(false, "pin", 3, 2).mode == FrequencyAdjustmentMode::Disabled,
            "Disabled learning still requested ranking.");
    Require(EngineFrequencyOptions(true, "pin", 3, 2).mode == FrequencyAdjustmentMode::Pin &&
                EngineFrequencyOptions(true, "halve", 1, 1).mode == FrequencyAdjustmentMode::Halve &&
                EngineFrequencyOptions(true, "linear", 2, 4).linear_step == 4 &&
                EngineFrequencyOptions(true, "promote", 1, 1).mode == FrequencyAdjustmentMode::Promote,
            "Learning-on options did not match the stored Windows modes.");

    const std::filesystem::path dataDirectory =
        std::filesystem::temp_directory_path() /
        ("metasequoia-frequency-preference-" +
         std::to_string(std::chrono::high_resolution_clock::now().time_since_epoch().count()));
    std::filesystem::create_directories(dataDirectory);
    if (setenv("METASEQUOIA_IME_DATA_DIR", dataDirectory.c_str(), 1) != 0)
        throw std::runtime_error("Failed to set the frequency preference test directory.");
    SeedFrequencyFixture(dataDirectory / "msime.db");

    {
        auto options = SessionTestOptions();
        options.learning = true;
        options.frequency = EngineFrequencyOptions(true, "pin", 1, 1);
        metasequoia::Session session(options);
        TypeNi(session);
        Require(session.select(5).commit == "己", "Pin selection failed.");
    }
    {
        auto options = SessionTestOptions();
        options.learning = true;
        options.frequency = EngineFrequencyOptions(true, "pin", 1, 1);
        metasequoia::Session reopened(options);
        TypeNi(reopened);
        Require(IndexOf(reopened.snapshot().candidates, "己") == 0,
                "Controller frequency options did not persist the Windows pin ranking.");
    }

    user_dictionary::close_default_user_database();
    std::filesystem::remove_all(dataDirectory);
    return 0;
}
} // namespace

int main()
{
    try
    {
        return RunTest();
    }
    catch (const std::exception &exception)
    {
        std::fprintf(stderr, "%s\n", exception.what());
        return 1;
    }
}
