import Foundation

/// 高频多字短语的常用英译人工补齐。
/// 背景：CC-CEDICT 没有「你好吗」这类整句短语（逐词拼又生硬，如 hello+question particle），
/// 故常用短语在此显式给出，查词时优先命中；未收录的长词再走「精确查＋贪心分词」兜底。
enum PhraseGlossary {
    static let zhToEn: [String: String] = [
        "你好吗": "How are you", "你好": "hello", "早上好": "Good morning", "晚上好": "Good evening",
        "晚安": "Good night", "再见": "goodbye", "谢谢你": "Thank you", "谢谢": "thanks",
        "对不起": "I'm sorry", "没关系": "never mind", "没问题": "No problem", "不客气": "You're welcome",
        "我爱你": "I love you", "我想你": "I miss you", "不知道": "I don't know", "明白了": "Got it",
        "多少钱": "How much", "怎么样": "How about", "为什么": "Why", "是不是": "Is it",
        "可以吗": "Is it okay", "怎么办": "What to do", "什么时候": "When", "什么地方": "Where",
        "干什么": "What are you doing", "在干什么": "What are you doing", "请问": "Excuse me",
        "你在干什么": "What are you doing", "你在做什么": "What are you doing", "你在干嘛": "What are you doing", "你干什么": "What are you doing",
        "好的": "OK", "谢谢大家": "Thank you all",
        "一路顺风": "Have a good trip", "辛苦了": "Thanks for your hard work", "加油": "Cheer up",
        "无聊": "boring", "什么意思": "What does it mean", "怎么回事": "What happened",
        "大家好": "Hello everyone", "好久不见": "Long time no see", "我爱你吗": "Do you love me",
    ]

    /// 取短语英译；无则 nil。
    static func en(_ phrase: String) -> String? { zhToEn[phrase] }
}
