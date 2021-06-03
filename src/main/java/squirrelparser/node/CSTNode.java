package squirrelparser.node;

import java.util.ArrayList;
import java.util.List;

import squirrelparser.utils.StringUtils;

public class CSTNode {
	public final String ruleName;
	public final int pos;
	public final int len;
	public final CharSequence inputSubSequence;
	public final List<CSTNode> children;

	public CSTNode(Match match, String input) {
		this.ruleName = match.ruleName;
		this.pos = match.pos;
		this.len = match.len;
		this.inputSubSequence = input.subSequence(pos, pos + len);
		this.children = new ArrayList<>();
		for (var subClauseMatch : match.subClauseMatches) {
			collectChildren(subClauseMatch, input);
		}
	}

	/** Collect only named nodes into CST (where node name is ruleName). */
	private void collectChildren(Match subClauseMatch, String input) {
		if (subClauseMatch.ruleName != null) {
			children.add(new CSTNode(subClauseMatch, input));
		} else {
			for (var subSubClauseMatch : subClauseMatch.subClauseMatches) {
				collectChildren(subSubClauseMatch, input);
			}
		}
	}

	private void print(int indent) {
		for (int i = 0; i < indent; i++) {
			System.out.print("--");
		}
		System.out.println(toString());
		for (int i = 0; i < children.size(); i++) {
			children.get(i).print(indent + 1);
		}
	}

	/** Print the tree. */
	public void print() {
		print(0);
	}

	@Override
	public String toString() {
		return ruleName + " : " + pos + "+" + len + " : [" + StringUtils.escapeString(inputSubSequence) + "]";
	}
}
