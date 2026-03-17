import Foundation

public struct Contact {
    public let id: String
    public let name: String
    public let initial: String
    public let avatarColor: UInt32
    public let section: String // 拼音首字母分组

    public init(id: String, name: String, initial: String, avatarColor: UInt32, section: String) {
        self.id = id
        self.name = name
        self.initial = initial
        self.avatarColor = avatarColor
        self.section = section
    }
}

public struct MockContactData {
    private static let avatarColors: [UInt32] = [
        0x07C160, 0x576B95, 0xFA9D3B, 0xE75A5A, 0x8B72BE,
        0x2AAE67, 0xCC6633, 0x3399CC, 0xE6567A, 0x44BB77
    ]

    // (name, pinyinInitial)
    private static let contacts: [(String, String)] = [
        ("艾伦", "A"), ("安琪", "A"),
        ("白雪", "B"), ("毕加索", "B"), ("蔡琴", "C"), ("陈静", "C"), ("陈伟", "C"),
        ("邓超", "D"), ("丁磊", "D"), ("董明", "D"),
        ("范冰", "F"), ("冯晨", "F"), ("傅雷", "F"),
        ("高远", "G"), ("郭靖", "G"), ("龚琳", "G"),
        ("韩雪", "H"), ("何冰", "H"), ("胡军", "H"), ("黄丽", "H"),
        ("贾宝", "J"), ("蒋介", "J"), ("金庸", "J"),
        ("孔明", "K"),
        ("李娜", "L"), ("梁思", "L"), ("林黛", "L"), ("刘洋", "L"), ("罗琳", "L"), ("吕布", "L"),
        ("马超", "M"), ("孟浩", "M"),
        ("倪萍", "N"),
        ("潘安", "P"), ("彭湃", "P"),
        ("秦始", "Q"), ("邱淑", "Q"),
        ("任盈", "R"),
        ("沈默", "S"), ("宋雨", "S"), ("苏轼", "S"), ("孙艳", "S"),
        ("唐风", "T"), ("陶渊", "T"),
        ("王芳", "W"), ("魏征", "W"), ("吴敏", "W"),
        ("萧峰", "X"), ("薛涛", "X"), ("徐强", "X"), ("许巍", "X"),
        ("杨帆", "Y"), ("叶问", "Y"), ("余华", "Y"), ("袁术", "Y"),
        ("曾国", "Z"), ("张伟", "Z"), ("赵磊", "Z"), ("周杰", "Z"), ("朱婷", "Z"),
    ]

    public static func generate() -> (sections: [String], grouped: [String: [Contact]]) {
        var grouped: [String: [Contact]] = [:]
        for (i, (name, pinyin)) in contacts.enumerated() {
            let contact = Contact(
                id: "contact_\(i)",
                name: name,
                initial: String(name.prefix(1)),
                avatarColor: avatarColors[i % avatarColors.count],
                section: pinyin
            )
            grouped[pinyin, default: []].append(contact)
        }
        let sections = grouped.keys.sorted()
        return (sections, grouped)
    }
}
