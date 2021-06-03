package squirrelparser.utils;

public class Utils {

	public static String chrToStrEscaped(char chr) {
		switch (chr) {
		case '\'':
			return "\\'";
		case '\n':
			return "\\n";
		case '\r':
			return "\\r";
		case '\t':
			return "\\t";
		case '\b':
			return "\\b";
		default:
			if (chr < 32 || chr > 126) {
				String hex = "000" + Integer.toHexString(chr);
				return "\\u" + hex.substring(hex.length() - 4);
			} else {
				return Character.toString(chr);
			}
		}
	}

	public static String strEscaped(String str) {
		var buf = new StringBuilder();
		for (int i = 0; i < str.length(); i++) {
			buf.append(chrToStrEscaped(str.charAt(i)));
		}
		return buf.toString();
	}

}
