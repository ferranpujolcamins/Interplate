import Foundation
import Interplate

class Template1: Renderer {
    let names: [String]
    init(names: [String]) {
        self.names = names
    }

    var greetings: Template {
        return "Hello"
    }

    override var template: Template {
        return """
        \(trim: .whitespacesAndNewlines)


        \(greetings),\n\(indent: 2, indentFirstLine: true, """
        \(for: names, where: { name in name.count > 2 }, do: { name, loop in
            "\(name)\(loop.end ? "!" : loop.index + 1 == loop.length - 1 ? " and " : ", ")"
        }, empty: "nobody")
        """)
        """
    }
}

let names = ["Foo", "Bar", "FooBar"]
print(Template1(names: names).render())

extension Template.StringInterpolation {
    static let dateFormatter = DateFormatter()
    func appendInterpolation(date: Date = Date(), format: String) {
        Template.StringInterpolation.dateFormatter.dateFormat = format
        appendLiteral(Template.StringInterpolation.dateFormatter.string(from: date))
    }

    func appendInterpolation(h1 body: Template) {
        appendInterpolation("<h1>\(body)</h1>" as Template)
    }
}


class Template2: Template1 {
    override var greetings: Template {
        return "\(super.greetings)-\(super.greetings)"
    }
    override var template: Template {
        return """
        \(super.template)
        Today is \(h1: "\(date: Date(), format: "y-MM-dd")")
        """
    }
}
print(Template2(names: names).render())