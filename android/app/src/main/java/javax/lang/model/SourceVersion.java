package javax.lang.model;

import java.util.HashSet;
import java.util.Set;

/**
 * Minimal stub of javax.lang.model.SourceVersion for Android.
 * The real class lives in java.compiler which Android does not ship.
 * GraphHopper core only calls {@link #isKeyword(CharSequence)}.
 */
public final class SourceVersion {

    private static final Set<String> KEYWORDS = new HashSet<>();

    static {
        String[] kw = {
            "abstract", "assert", "boolean", "break", "byte", "case", "catch",
            "char", "class", "const", "continue", "default", "do", "double",
            "else", "enum", "extends", "final", "finally", "float", "for",
            "goto", "if", "implements", "import", "instanceof", "int",
            "interface", "long", "native", "new", "package", "private",
            "protected", "public", "return", "short", "static", "strictfp",
            "super", "switch", "synchronized", "this", "throw", "throws",
            "transient", "try", "void", "volatile", "while",
            "true", "false", "null"
        };
        for (String k : kw) KEYWORDS.add(k);
    }

    private SourceVersion() {}

    public static boolean isKeyword(CharSequence s) {
        return s != null && KEYWORDS.contains(s.toString());
    }

    public static boolean isName(CharSequence name) {
        if (name == null || name.length() == 0) return false;
        String s = name.toString();
        for (String part : s.split("\\.", -1)) {
            if (part.isEmpty() || isKeyword(part) || !isIdentifier(part))
                return false;
        }
        return true;
    }

    public static boolean isIdentifier(CharSequence name) {
        if (name == null || name.length() == 0) return false;
        String s = name.toString();
        if (!Character.isJavaIdentifierStart(s.charAt(0))) return false;
        for (int i = 1; i < s.length(); i++) {
            if (!Character.isJavaIdentifierPart(s.charAt(i))) return false;
        }
        return true;
    }
}
