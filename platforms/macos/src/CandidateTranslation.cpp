#include "CandidateTranslation.h"

#include "common/helpcode_utils.h"
#include "english/english_dictionary.h"

#include <vector>

namespace metasequoia::mac
{
namespace
{
bool IsAsciiSpace(unsigned char ch)
{
    return ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n';
}

std::string CollapseWhitespace(const std::string &text)
{
    std::string out;
    out.reserve(text.size());
    bool pending_space = false;
    for (const unsigned char ch : text)
    {
        if (IsAsciiSpace(ch))
        {
            pending_space = !out.empty();
            continue;
        }
        if (pending_space)
        {
            out.push_back(' ');
            pending_space = false;
        }
        out.push_back(static_cast<char>(ch));
    }
    return out;
}

std::string TakeLeadingSenses(const std::string &text, size_t limit)
{
    if (limit == 0 || text.empty())
        return {};
    std::vector<std::string> senses;
    size_t begin = 0;
    while (begin <= text.size() && senses.size() < limit)
    {
        const size_t end = text.find_first_of(";；", begin);
        const size_t stop = end == std::string::npos ? text.size() : end;
        std::string sense = CollapseWhitespace(text.substr(begin, stop - begin));
        if (!sense.empty())
            senses.push_back(std::move(sense));
        if (end == std::string::npos)
            break;
        begin = end + 1;
    }
    std::string joined;
    for (size_t index = 0; index < senses.size(); ++index)
    {
        if (index > 0)
            joined += "; ";
        joined += senses[index];
    }
    return joined;
}

bool IsEnglishCandidateText(const std::string &visible, std::string &normalized)
{
    bool has_ascii_letter = false;
    normalized.clear();
    normalized.reserve(visible.size());
    for (const unsigned char ch : visible)
    {
        if (ch >= 'A' && ch <= 'Z')
        {
            normalized.push_back(static_cast<char>(ch + ('a' - 'A')));
            has_ascii_letter = true;
        }
        else if (ch >= 'a' && ch <= 'z')
        {
            normalized.push_back(static_cast<char>(ch));
            has_ascii_letter = true;
        }
        else if (ch == ' ' || ch == '-' || ch == '\'')
        {
            normalized.push_back(static_cast<char>(ch));
        }
        else
        {
            return false;
        }
    }
    return has_ascii_letter;
}
} // namespace

std::optional<TranslationQuery> TranslationQueryForCandidate(const WordItem &item)
{
    if (item.word.empty() || item.source == CandidateSource::Emoji || item.source == CandidateSource::Kaomoji)
        return std::nullopt;
    if (item.source == CandidateSource::EnglishDictionary && !item.pinyin.empty())
        return TranslationQuery{item.pinyin, TranslationDirection::EnglishToChinese};

    std::string normalized;
    if (IsEnglishCandidateText(item.word, normalized))
        return TranslationQuery{std::move(normalized), TranslationDirection::EnglishToChinese};
    if (HelpcodeUtils::count_han_chars(item.word) > 0)
        return TranslationQuery{item.word, TranslationDirection::ChineseToEnglish};
    return std::nullopt;
}

std::string FormatCandidateGloss(const std::string &text)
{
    return TakeLeadingSenses(text, 2);
}

std::string LookupCandidateGloss(EnglishDictionary &dictionary, const TranslationQuery &query)
{
    if (query.key.empty())
        return {};
    const std::string raw = query.direction == TranslationDirection::EnglishToChinese
                                ? dictionary.query_chinese_gloss(query.key)
                                : dictionary.query_english_gloss(query.key);
    return FormatCandidateGloss(raw);
}
} // namespace metasequoia::mac
