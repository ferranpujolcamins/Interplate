import Foundation
import Prelude

public final class StringTemplate: Monoid {
    public let template: Template
    public let args: [CVarArg]

    init(template: Template, args: [CVarArg]) {
        self.template = template
        self.args = args
    }

    public static var empty: StringTemplate {
        return StringTemplate(template: .empty, args: [])
    }

    public static func <> (lhs: StringTemplate, rhs: StringTemplate) -> StringTemplate {
        return StringTemplate(template: lhs.template <> rhs.template, args: lhs.args <> rhs.args)
    }

    func render() -> String {
        return template.render()
    }
}

public struct StringFormat<A> {
    let parser: Parser<StringTemplate, A>
    public let format: Format<A>

    init(_ parser: Parser<StringTemplate, A>) {
        self.parser = parser
        self.format = Format<A>(parse: { (template) -> (rest: Template, match: A)? in
            guard let match = parser.parse(StringTemplate(template: template, args: [])) else { return nil }
            return (rest: match.rest.template, match: match.match)
        }, print: { (a) -> Template? in
            parser.print(a)?.template
        }) { (a) -> Template? in
            parser.template(a)?.template
        }
    }

    init(
        parse: @escaping (StringTemplate) -> (rest: StringTemplate, match: A)?,
        print: @escaping (A) -> StringTemplate?,
        template: @escaping (A) -> StringTemplate?
        ) {
        self.init(Parser<StringTemplate, A>(parse: parse, print: print, template: template))
    }

    public func render(_ a: A) -> String? {
        guard let template = parser.print(a) else { return nil }
        return String(format: template.render(), arguments: template.args)
    }

    public func localized(_ a: A, table: String? = nil, bundle: Bundle = .main, value: String? = nil) -> String? {
        print("localizing")
        guard let template = parser.print(a) else { return nil }
        return String(
            format: bundle.localizedString(forKey: template.render(), value: value, table: table),
            arguments: template.args
        )
    }

    public func match(_ template: StringTemplate) -> A? {
        return (self <% end).parser.parse(template)?.match
    }

    public func template(for a: A) -> StringTemplate? {
        return self.parser.print(a)
    }

    public func render(templateFor a: A) -> String? {
        return self.parser.template(a).flatMap { $0.render() }
    }
}

extension StringFormat: ExpressibleByStringInterpolation {

    public init(stringLiteral value: String) {
        self.init(slit(String(value)).map(.any))
    }

    public init(stringInterpolation: StringInterpolation) {
        if stringInterpolation.parsers.isEmpty {
            self.init(.empty)
        } else {
            let parser = reduce(parsers: stringInterpolation.parsers)
            self.init(parser.map(.any))
        }
    }

    public class StringInterpolation: StringInterpolationProtocol {
        private(set) var parsers: [(Parser<StringTemplate, Any>, Any.Type)] = []

        public required init(literalCapacity: Int, interpolationCount: Int) {
        }

        public func appendParser<A>(_ parser: Parser<StringTemplate, A>) {
            parsers.append((parser.map(.any), A.self))
        }

        public func appendLiteral(_ literal: String) {
            appendParser(slit(literal))
        }

        public func appendInterpolation<A>(_ paramIso: PartialIso<String, A>) where A: StringFormatting {
            appendParser(sparam(paramIso))
        }

        public func appendInterpolation<A>(_ paramIso: PartialIso<String, A>, index: UInt) where A: StringFormatting {
            appendParser(sparam(paramIso, index: index))
        }
    }

}

public protocol StringFormatting {
    static var format: String { get }
    var arg: CVarArg { get }
}

#if canImport(ObjectiveC)
extension NSObject: StringFormatting {
    static public var format: String { return "@" }
    public var arg: CVarArg { return self }
}
#endif

extension Prelude.Unit: StringFormatting {
    static public var format: String { return "" }
    public var arg: CVarArg { return "" }
}

extension Character: StringFormatting {
    static public var format: String { return "c" }
    public var arg: CVarArg { return UnicodeScalar(String(self))!.value }
}

extension String: StringFormatting {
    static public var format: String { return "@" }
    public var arg: CVarArg { return self }
}

extension CChar: StringFormatting {
    static public var format: String { return "hhd" }
    public var arg: CVarArg { return self }
}

extension CShort: StringFormatting {
    static public var format: String { return "hd" }
    public var arg: CVarArg { return self }
}

extension CLong: StringFormatting {
    static public var format: String { return "ld" }
    public var arg: CVarArg { return self }
}

extension CLongLong: StringFormatting {
    static public var format: String { return "lld" }
    public var arg: CVarArg { return self }
}

#if os(macOS)
extension Float80: StringFormatting {
    static public var format: String { return "Lf" }
    public var arg: CVarArg { return self }
}
#else
extension Double: StringFormatting {
    static public var format: String { return "Lf" }
    public var arg: CVarArg { return self }
}
#endif

extension PartialIso where A == String, B: StringFormatting {
    public var formatted: PartialIso {
        return PartialIso(
            apply: apply,
            unapply: { _ in "%\(B.format)" }
        )
    }

    public func formatted(index: UInt) -> PartialIso {
        return PartialIso(
            apply: apply,
            unapply: { _ in "%\(index)$\(B.format)" }
        )
    }
}

extension StringFormat {

    /// A Format that always fails and doesn't print anything.
    public static var empty: StringFormat {
        return .init(.empty)
    }

    public func map<B>(_ f: PartialIso<A, B>) -> StringFormat<B> {
        return .init(parser.map(f))
    }

    public static func <¢> <B> (lhs: PartialIso<A, B>, rhs: StringFormat) -> StringFormat<B> {
        return .init(lhs <¢> rhs.parser)
    }

    /// Processes with the left side Format, and if that fails uses the right side Format.
    public static func <|> (lhs: StringFormat, rhs: StringFormat) -> StringFormat {
        return .init(lhs.parser <|> rhs.parser)
    }

    /// Processes with the left and right side Formats, and if they succeed returns the pair of their results.
    public static func <%> <B> (lhs: StringFormat, rhs: StringFormat<B>) -> StringFormat<(A, B)> {
        return .init(lhs.parser <%> rhs.parser)
    }

    /// Processes with the left and right side Formats, discarding the result of the left side.
    public static func %> (x: StringFormat<Prelude.Unit>, y: StringFormat) -> StringFormat {
        return .init(x.parser %> y.parser)
    }
}

extension StringFormat where A == Prelude.Unit {
    /// Processes with the left and right Formats, discarding the result of the right side.
    public static func <% <B>(x: StringFormat<B>, y: StringFormat) -> StringFormat<B> {
        return .init(x.parser <% y.parser)
    }
}

private let end = StringFormat<Prelude.Unit>(
    parse: { format in
        format.template.parts.isEmpty
            ? (StringTemplate(template: Template(parts: []), args: []), unit)
            : nil
},
    print: const(.empty),
    template: const(.empty)
)

public func slit(_ str: String) -> Parser<StringTemplate, Prelude.Unit> {
    return Parser<StringTemplate, Prelude.Unit>(
        parse: { format in
            head(format.template.parts).flatMap { (p, ps) in
                return p == str
                    ? (StringTemplate(template: Template(parts: ps), args: []), unit)
                    : nil
            }
    },
        print: { _ in StringTemplate(template: Template(parts: [str]), args: []) },
        template: { _ in StringTemplate(template: Template(parts: [str]), args: []) }
    )
}

public func slit(_ str: String) -> StringFormat<Prelude.Unit> {
    return StringFormat<Prelude.Unit>(slit(str))
}

private func _sparam<A: StringFormatting>(_ f: PartialIso<String, A>) -> Parser<StringTemplate, A> {
    return Parser<StringTemplate, A>(
        parse: { format in
            guard let (p, ps) = head(format.template.parts), let v = f.apply(p) else { return nil }
            return (StringTemplate(template: Template(parts: ps), args: [v.arg]), v)
    },
        print: { a in
            f.unapply(a).flatMap {
                StringTemplate(
                    template: Template(parts: [String(format: $0, a.arg)]),
                    args: [
                        a.arg
                    ]
                )
            }
    },
        template: { a in
            f.unapply(a).flatMap {
                StringTemplate(
                    template: Template(parts: [$0]),
                    args: [
                        a.arg
                    ]
                )
            }
    })
}

public func sparam<A: StringFormatting>(_ f: PartialIso<String, A>) -> Parser<StringTemplate, A> {
    return _sparam(f.formatted)
}

public func sparam<A: StringFormatting>(_ f: PartialIso<String, A>, index: UInt) -> Parser<StringTemplate, A> {
    return _sparam(f.formatted(index: index))
}

public func sparam<A: StringFormatting>(_ f: PartialIso<String, A>) -> StringFormat<A> {
    return StringFormat<A>(sparam(f))
}

public func sparam<A: StringFormatting>(_ f: PartialIso<String, A>, index: UInt) -> StringFormat<A> {
    return StringFormat<A>(sparam(f, index: index))
}

extension StringFormat {

    public func render<A1, B>(_ a: A1, _ b: B) -> String? where A == (A1, B)
    {
        return render((a, b))
    }

    public func localized<A1, B>(_ a: A1, _ b: B, table: String? = nil, bundle: Bundle = .main, value: String? = nil) -> String? where A == (A1, B)
    {
        return localized((a, b), table: table, bundle: bundle, value: value)
    }

    public func template<A1, B>(_ a: A1, _ b: B) -> Template? where A == (A1, B)
    {
        return self.parser.print((a, b))?.template
    }

    public func render<A1, B>(templateFor a: A1, _ b: B) -> String? where A == (A1, B)
    {
        return self.parser.template((a, b)).flatMap { $0.render() }
    }

}

extension StringFormat {

    public func render<A1, B, C>(_ a: A1, _ b: B, _ c: C) -> String? where A == (A1, (B, C))
    {
        return render(parenthesize(a, b, c))
    }

    public func localized<A1, B, C>(_ a: A1, _ b: B, _ c: C, table: String? = nil, bundle: Bundle = .main, value: String? = nil) -> String? where A == (A1, (B, C))
    {
        return localized(parenthesize(a, b, c), table: table, bundle: bundle, value: value)
    }

    public func template<A1, B, C>(_ a: A1, _ b: B, _ c: C) -> Template? where A == (A1, (B, C))
    {
        return self.parser.print(parenthesize(a, b, c))?.template
    }

    public func render<A1, B, C>(templateFor a: A1, _ b: B, _ c: C) -> String? where A == (A1, (B, C))
    {
        return self.parser.template(parenthesize(a, b, c)).flatMap { $0.render() }
    }

}

extension StringFormat {

    public func render<A1, B, C, D>(_ a: A1, _ b: B, _ c: C, _ d: D) -> String? where A == (A1, (B, (C, D)))
    {
        return render(parenthesize(a, b, c, d))
    }

    public func localized<A1, B, C, D>(_ a: A1, _ b: B, _ c: C, _ d: D, table: String? = nil, bundle: Bundle = .main, value: String? = nil) -> String? where A == (A1, (B, (C, D)))
    {
        return localized(parenthesize(a, b, c, d), table: table, bundle: bundle, value: value)
    }

    public func template<A1, B, C, D>(_ a: A1, _ b: B, _ c: C, _ d: D) -> Template? where A == (A1, (B, (C, D)))
    {
        return self.parser.print(parenthesize(a, b, c, d))?.template
    }

    public func render<A1, B, C, D>(templateFor a: A1, _ b: B, _ c: C, _ d: D) -> String? where A == (A1, (B, (C, D)))
    {
        return self.parser.template(parenthesize(a, b, c, d)).flatMap { $0.render() }
    }

}
