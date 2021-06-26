
	CompilationUnit = rule { ((Spacing) ~ (optional(PackageDeclaration)) ~ (zeroOrMore(ImportDeclaration)) ~ (zeroOrMore(TypeDeclaration))) }
	PackageDeclaration = rule { ((zeroOrMore(Annotation)) ~ ((("package") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (QualifiedIdentifier) ~ ((";") ~ (Spacing)))) }
	ImportDeclaration = rule { ((("import") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (optional(("static") ~ (!(LetterOrDigit)) ~ (Spacing))) ~ (QualifiedIdentifier) ~ (optional(((".") ~ (Spacing)) ~ (("*") ~ (!("=")) ~ (Spacing)))) ~ ((";") ~ (Spacing))) }
	TypeDeclaration = rule { (((zeroOrMore(Modifier)) ~ ((ClassDeclaration) | (EnumDeclaration) | (InterfaceDeclaration) | (AnnotationTypeDeclaration))) | ((";") ~ (Spacing))) }
	ClassDeclaration = rule { ((("class") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Identifier) ~ (optional(TypeParameters)) ~ (optional((("extends") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ClassType))) ~ (optional((("implements") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ClassTypeList))) ~ (ClassBody)) }
	ClassBody = rule { ((("{") ~ (Spacing)) ~ (zeroOrMore(ClassBodyDeclaration)) ~ (("}") ~ (Spacing))) }
	ClassBodyDeclaration = rule { (((";") ~ (Spacing)) | ((optional(("static") ~ (!(LetterOrDigit)) ~ (Spacing))) ~ (Block)) | ((zeroOrMore(Modifier)) ~ (MemberDecl))) }
	MemberDecl = rule { (((TypeParameters) ~ (GenericMethodOrConstructorRest)) | ((Type) ~ (Identifier) ~ (MethodDeclaratorRest)) | ((Type) ~ (VariableDeclarators) ~ ((";") ~ (Spacing))) | ((("void") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Identifier) ~ (VoidMethodDeclaratorRest)) | ((Identifier) ~ (ConstructorDeclaratorRest)) | (InterfaceDeclaration) | (ClassDeclaration) | (EnumDeclaration) | (AnnotationTypeDeclaration)) }
	GenericMethodOrConstructorRest = rule { ((((Type) | (("void") ~ (!(LetterOrDigit)) ~ (Spacing))) ~ (Identifier) ~ (MethodDeclaratorRest)) | ((Identifier) ~ (ConstructorDeclaratorRest))) }
	MethodDeclaratorRest = rule { ((FormalParameters) ~ (zeroOrMore(Dim)) ~ (optional((("throws") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ClassTypeList))) ~ ((MethodBody) | ((";") ~ (Spacing)))) }
	VoidMethodDeclaratorRest = rule { ((FormalParameters) ~ (optional((("throws") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ClassTypeList))) ~ ((MethodBody) | ((";") ~ (Spacing)))) }
	ConstructorDeclaratorRest = rule { ((FormalParameters) ~ (optional((("throws") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ClassTypeList))) ~ (MethodBody)) }
	MethodBody = rule { (Block) }
	InterfaceDeclaration = rule { ((("interface") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Identifier) ~ (optional(TypeParameters)) ~ (optional((("extends") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ClassTypeList))) ~ (InterfaceBody)) }
	InterfaceBody = rule { ((("{") ~ (Spacing)) ~ (zeroOrMore(InterfaceBodyDeclaration)) ~ (("}") ~ (Spacing))) }
	InterfaceBodyDeclaration = rule { (((zeroOrMore(Modifier)) ~ (InterfaceMemberDecl)) | ((";") ~ (Spacing))) }
	InterfaceMemberDecl = rule { ((InterfaceMethodOrFieldDecl) | (InterfaceGenericMethodDecl) | ((("void") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Identifier) ~ (VoidInterfaceMethodDeclaratorsRest)) | (InterfaceDeclaration) | (AnnotationTypeDeclaration) | (ClassDeclaration) | (EnumDeclaration)) }
	InterfaceMethodOrFieldDecl = rule { (((Type) ~ (Identifier)) ~ (InterfaceMethodOrFieldRest)) }
	InterfaceMethodOrFieldRest = rule { (((ConstantDeclaratorsRest) ~ ((";") ~ (Spacing))) | (InterfaceMethodDeclaratorRest)) }
	InterfaceMethodDeclaratorRest = rule { ((FormalParameters) ~ (zeroOrMore(Dim)) ~ (optional((("throws") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ClassTypeList))) ~ ((";") ~ (Spacing))) }
	InterfaceGenericMethodDecl = rule { ((TypeParameters) ~ ((Type) | (("void") ~ (!(LetterOrDigit)) ~ (Spacing))) ~ (Identifier) ~ (InterfaceMethodDeclaratorRest)) }
	VoidInterfaceMethodDeclaratorsRest = rule { ((FormalParameters) ~ (optional((("throws") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ClassTypeList))) ~ ((";") ~ (Spacing))) }
	ConstantDeclaratorsRest = rule { ((ConstantDeclaratorRest) ~ (zeroOrMore(((",") ~ (Spacing)) ~ (ConstantDeclarator)))) }
	ConstantDeclarator = rule { ((Identifier) ~ (ConstantDeclaratorRest)) }
	ConstantDeclaratorRest = rule { ((zeroOrMore(Dim)) ~ (("=") ~ (!("=")) ~ (Spacing)) ~ (VariableInitializer)) }
	EnumDeclaration = rule { ((("enum") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Identifier) ~ (optional((("implements") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ClassTypeList))) ~ (EnumBody)) }
	EnumBody = rule { ((("{") ~ (Spacing)) ~ (optional(EnumConstants)) ~ (optional((",") ~ (Spacing))) ~ (optional(EnumBodyDeclarations)) ~ (("}") ~ (Spacing))) }
	EnumConstants = rule { ((EnumConstant) ~ (zeroOrMore(((",") ~ (Spacing)) ~ (EnumConstant)))) }
	EnumConstant = rule { ((zeroOrMore(Annotation)) ~ (Identifier) ~ (optional(Arguments)) ~ (optional(ClassBody))) }
	EnumBodyDeclarations = rule { (((";") ~ (Spacing)) ~ (zeroOrMore(ClassBodyDeclaration))) }
	LocalVariableDeclarationStatement = rule { ((zeroOrMore((("final") ~ (!(LetterOrDigit)) ~ (Spacing)) | (Annotation))) ~ (Type) ~ (VariableDeclarators) ~ ((";") ~ (Spacing))) }
	VariableDeclarators = rule { ((VariableDeclarator) ~ (zeroOrMore(((",") ~ (Spacing)) ~ (VariableDeclarator)))) }
	VariableDeclarator = rule { ((Identifier) ~ (zeroOrMore(Dim)) ~ (optional((("=") ~ (!("=")) ~ (Spacing)) ~ (VariableInitializer)))) }
	FormalParameters = rule { ((("(") ~ (Spacing)) ~ (optional(FormalParameterDecls)) ~ ((")") ~ (Spacing))) }
	FormalParameter = rule { ((zeroOrMore((("final") ~ (!(LetterOrDigit)) ~ (Spacing)) | (Annotation))) ~ (Type) ~ (VariableDeclaratorId)) }
	FormalParameterDecls = rule { ((zeroOrMore((("final") ~ (!(LetterOrDigit)) ~ (Spacing)) | (Annotation))) ~ (Type) ~ (FormalParameterDeclsRest)) }
	FormalParameterDeclsRest = rule { (((VariableDeclaratorId) ~ (optional(((",") ~ (Spacing)) ~ (FormalParameterDecls)))) | ((("...") ~ (Spacing)) ~ (VariableDeclaratorId))) }
	VariableDeclaratorId = rule { ((Identifier) ~ (zeroOrMore(Dim))) }
	Block = rule { ((("{") ~ (Spacing)) ~ (BlockStatements) ~ (("}") ~ (Spacing))) }
	BlockStatements = rule { (zeroOrMore(BlockStatement)) }
	BlockStatement = rule { ((LocalVariableDeclarationStatement) | ((zeroOrMore(Modifier)) ~ ((ClassDeclaration) | (EnumDeclaration))) | (Statement)) }
	Statement = rule { ((Block) | ((("assert") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Expression) ~ (optional(((":") ~ (Spacing)) ~ (Expression))) ~ ((";") ~ (Spacing))) | ((("if") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ParExpression) ~ (Statement) ~ (optional((("else") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Statement)))) | ((("for") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (("(") ~ (Spacing)) ~ (optional(ForInit)) ~ ((";") ~ (Spacing)) ~ (optional(Expression)) ~ ((";") ~ (Spacing)) ~ (optional(ForUpdate)) ~ ((")") ~ (Spacing)) ~ (Statement)) | ((("for") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (("(") ~ (Spacing)) ~ (FormalParameter) ~ ((":") ~ (Spacing)) ~ (Expression) ~ ((")") ~ (Spacing)) ~ (Statement)) | ((("while") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ParExpression) ~ (Statement)) | ((("do") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Statement) ~ (("while") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ParExpression) ~ ((";") ~ (Spacing))) | ((("try") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Block) ~ (((oneOrMore(Catch_)) ~ (optional(Finally_))) | (Finally_))) | ((("switch") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ParExpression) ~ (("{") ~ (Spacing)) ~ (SwitchBlockStatementGroups) ~ (("}") ~ (Spacing))) | ((("synchronized") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ParExpression) ~ (Block)) | ((("return") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (optional(Expression)) ~ ((";") ~ (Spacing))) | ((("throw") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Expression) ~ ((";") ~ (Spacing))) | ((("break") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (optional(Identifier)) ~ ((";") ~ (Spacing))) | ((("continue") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (optional(Identifier)) ~ ((";") ~ (Spacing))) | (((Identifier) ~ ((":") ~ (Spacing))) ~ (Statement)) | ((StatementExpression) ~ ((";") ~ (Spacing))) | ((";") ~ (Spacing))) }
	Catch_ = rule { ((("catch") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (("(") ~ (Spacing)) ~ (FormalParameter) ~ ((")") ~ (Spacing)) ~ (Block)) }
	Finally_ = rule { ((("finally") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Block)) }
	SwitchBlockStatementGroups = rule { (zeroOrMore(SwitchBlockStatementGroup)) }
	SwitchBlockStatementGroup = rule { ((SwitchLabel) ~ (BlockStatements)) }
	SwitchLabel = rule { (((("case") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ConstantExpression) ~ ((":") ~ (Spacing))) | ((("case") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (EnumConstantName) ~ ((":") ~ (Spacing))) | ((("default") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ ((":") ~ (Spacing)))) }
	ForInit = rule { (((zeroOrMore((("final") ~ (!(LetterOrDigit)) ~ (Spacing)) | (Annotation))) ~ (Type) ~ (VariableDeclarators)) | ((StatementExpression) ~ (zeroOrMore(((",") ~ (Spacing)) ~ (StatementExpression))))) }
	ForUpdate = rule { ((StatementExpression) ~ (zeroOrMore(((",") ~ (Spacing)) ~ (StatementExpression)))) }
	EnumConstantName = rule { (Identifier) }
	StatementExpression = rule { (Expression) }
	ConstantExpression = rule { (Expression) }
	Expression = rule { ((ConditionalExpression) ~ (zeroOrMore((AssignmentOperator) ~ (ConditionalExpression)))) }
	AssignmentOperator = rule { ((("=") ~ (!("=")) ~ (Spacing)) | (("+=") ~ (Spacing)) | (("-=") ~ (Spacing)) | (("*=") ~ (Spacing)) | (("/=") ~ (Spacing)) | (("&=") ~ (Spacing)) | (("|=") ~ (Spacing)) | (("^=") ~ (Spacing)) | (("%=") ~ (Spacing)) | (("<<=") ~ (Spacing)) | ((">>=") ~ (Spacing)) | ((">>>=") ~ (Spacing))) }
	ConditionalExpression = rule { ((ConditionalOrExpression) ~ (zeroOrMore((("?") ~ (Spacing)) ~ (Expression) ~ ((":") ~ (Spacing)) ~ (ConditionalOrExpression)))) }
	ConditionalOrExpression = rule { ((ConditionalAndExpression) ~ (zeroOrMore((("||") ~ (Spacing)) ~ (ConditionalAndExpression)))) }
	ConditionalAndExpression = rule { ((InclusiveOrExpression) ~ (zeroOrMore((("&&") ~ (Spacing)) ~ (InclusiveOrExpression)))) }
	InclusiveOrExpression = rule { ((ExclusiveOrExpression) ~ (zeroOrMore((("|") ~ (!(anyOf("=|"))) ~ (Spacing)) ~ (ExclusiveOrExpression)))) }
	ExclusiveOrExpression = rule { ((AndExpression) ~ (zeroOrMore((("^") ~ (!("=")) ~ (Spacing)) ~ (AndExpression)))) }
	AndExpression = rule { ((EqualityExpression) ~ (zeroOrMore((("&") ~ (!(anyOf("&="))) ~ (Spacing)) ~ (EqualityExpression)))) }
	EqualityExpression = rule { ((RelationalExpression) ~ (zeroOrMore(((("==") ~ (Spacing)) | (("!=") ~ (Spacing))) ~ (RelationalExpression)))) }
	RelationalExpression = rule { ((ShiftExpression) ~ (zeroOrMore((((("<=") ~ (Spacing)) | ((">=") ~ (Spacing)) | (("<") ~ (!(anyOf("<="))) ~ (Spacing)) | ((">") ~ (!(anyOf("=>"))) ~ (Spacing))) ~ (ShiftExpression)) | ((("instanceof") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ReferenceType))))) }
	ShiftExpression = rule { ((AdditiveExpression) ~ (zeroOrMore(((("<<") ~ (!("=")) ~ (Spacing)) | ((">>") ~ (!(anyOf("=>"))) ~ (Spacing)) | ((">>>") ~ (!("=")) ~ (Spacing))) ~ (AdditiveExpression)))) }
	AdditiveExpression = rule { ((MultiplicativeExpression) ~ (zeroOrMore(((("+") ~ (!(anyOf("+="))) ~ (Spacing)) | (("-") ~ (!(anyOf("-="))) ~ (Spacing))) ~ (MultiplicativeExpression)))) }
	MultiplicativeExpression = rule { ((UnaryExpression) ~ (zeroOrMore(((("*") ~ (!("=")) ~ (Spacing)) | (("/") ~ (!("=")) ~ (Spacing)) | (("%") ~ (!("=")) ~ (Spacing))) ~ (UnaryExpression)))) }
	UnaryExpression = rule { (((PrefixOp) ~ (UnaryExpression)) | ((("(") ~ (Spacing)) ~ (Type) ~ ((")") ~ (Spacing)) ~ (UnaryExpression)) | ((Primary) ~ (zeroOrMore(Selector)) ~ (zeroOrMore(PostFixOp)))) }
	Primary = rule { ((ParExpression) | ((NonWildcardTypeArguments) ~ ((ExplicitGenericInvocationSuffix) | ((("this") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Arguments)))) | ((("this") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (optional(Arguments))) | ((("super") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (SuperSuffix)) | (Literal) | ((("new") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Creator)) | ((QualifiedIdentifier) ~ (optional(IdentifierSuffix))) | ((BasicType) ~ (zeroOrMore(Dim)) ~ ((".") ~ (Spacing)) ~ (("class") ~ (!(LetterOrDigit)) ~ (Spacing))) | ((("void") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ ((".") ~ (Spacing)) ~ (("class") ~ (!(LetterOrDigit)) ~ (Spacing)))) }
	IdentifierSuffix = rule { (((("[") ~ (Spacing)) ~ (((("]") ~ (Spacing)) ~ (zeroOrMore(Dim)) ~ ((".") ~ (Spacing)) ~ (("class") ~ (!(LetterOrDigit)) ~ (Spacing))) | ((Expression) ~ (("]") ~ (Spacing))))) | (Arguments) | (((".") ~ (Spacing)) ~ ((("class") ~ (!(LetterOrDigit)) ~ (Spacing)) | (ExplicitGenericInvocation) | (("this") ~ (!(LetterOrDigit)) ~ (Spacing)) | ((("super") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Arguments)) | ((("new") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (optional(NonWildcardTypeArguments)) ~ (InnerCreator))))) }
	ExplicitGenericInvocation = rule { ((NonWildcardTypeArguments) ~ (ExplicitGenericInvocationSuffix)) }
	NonWildcardTypeArguments = rule { ((("<") ~ (Spacing)) ~ (ReferenceType) ~ (zeroOrMore(((",") ~ (Spacing)) ~ (ReferenceType))) ~ ((">") ~ (Spacing))) }
	ExplicitGenericInvocationSuffix = rule { (((("super") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (SuperSuffix)) | ((Identifier) ~ (Arguments))) }
	PrefixOp = rule { ((("++") ~ (Spacing)) | (("--") ~ (Spacing)) | (("!") ~ (!("=")) ~ (Spacing)) | (("~") ~ (Spacing)) | (("+") ~ (!(anyOf("+="))) ~ (Spacing)) | (("-") ~ (!(anyOf("-="))) ~ (Spacing))) }
	PostFixOp = rule { ((("++") ~ (Spacing)) | (("--") ~ (Spacing))) }
	Selector = rule { ((((".") ~ (Spacing)) ~ (Identifier) ~ (optional(Arguments))) | (((".") ~ (Spacing)) ~ (ExplicitGenericInvocation)) | (((".") ~ (Spacing)) ~ (("this") ~ (!(LetterOrDigit)) ~ (Spacing))) | (((".") ~ (Spacing)) ~ (("super") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (SuperSuffix)) | (((".") ~ (Spacing)) ~ (("new") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (optional(NonWildcardTypeArguments)) ~ (InnerCreator)) | (DimExpr)) }
	SuperSuffix = rule { ((Arguments) | (((".") ~ (Spacing)) ~ (Identifier) ~ (optional(Arguments)))) }
	BasicType = rule { ((("byte") | ("short") | ("char") | ("int") | ("long") | ("float") | ("double") | ("boolean")) ~ (!(LetterOrDigit)) ~ (Spacing)) }
	Arguments = rule { ((("(") ~ (Spacing)) ~ (optional((Expression) ~ (zeroOrMore(((",") ~ (Spacing)) ~ (Expression))))) ~ ((")") ~ (Spacing))) }
	Creator = rule { (((optional(NonWildcardTypeArguments)) ~ (CreatedName) ~ (ClassCreatorRest)) | ((optional(NonWildcardTypeArguments)) ~ ((ClassType) | (BasicType)) ~ (ArrayCreatorRest))) }
	CreatedName = rule { ((Identifier) ~ (optional(NonWildcardTypeArguments)) ~ (zeroOrMore(((".") ~ (Spacing)) ~ (Identifier) ~ (optional(NonWildcardTypeArguments))))) }
	InnerCreator = rule { ((Identifier) ~ (ClassCreatorRest)) }
	ArrayCreatorRest = rule { ((("[") ~ (Spacing)) ~ (((("]") ~ (Spacing)) ~ (zeroOrMore(Dim)) ~ (ArrayInitializer)) | ((Expression) ~ (("]") ~ (Spacing)) ~ (zeroOrMore(DimExpr)) ~ (zeroOrMore(Dim))))) }
	ClassCreatorRest = rule { ((Arguments) ~ (optional(ClassBody))) }
	ArrayInitializer = rule { ((("{") ~ (Spacing)) ~ (optional((VariableInitializer) ~ (zeroOrMore(((",") ~ (Spacing)) ~ (VariableInitializer))))) ~ (optional((",") ~ (Spacing))) ~ (("}") ~ (Spacing))) }
	VariableInitializer = rule { ((ArrayInitializer) | (Expression)) }
	ParExpression = rule { ((("(") ~ (Spacing)) ~ (Expression) ~ ((")") ~ (Spacing))) }
	QualifiedIdentifier = rule { ((Identifier) ~ (zeroOrMore(((".") ~ (Spacing)) ~ (Identifier)))) }
	Dim = rule { ((("[") ~ (Spacing)) ~ (("]") ~ (Spacing))) }
	DimExpr = rule { ((("[") ~ (Spacing)) ~ (Expression) ~ (("]") ~ (Spacing))) }
	Type = rule { (((BasicType) | (ClassType)) ~ (zeroOrMore(Dim))) }
	ReferenceType = rule { (((BasicType) ~ (oneOrMore(Dim))) | ((ClassType) ~ (zeroOrMore(Dim)))) }
	ClassType = rule { ((Identifier) ~ (optional(TypeArguments)) ~ (zeroOrMore(((".") ~ (Spacing)) ~ (Identifier) ~ (optional(TypeArguments))))) }
	ClassTypeList = rule { ((ClassType) ~ (zeroOrMore(((",") ~ (Spacing)) ~ (ClassType)))) }
	TypeArguments = rule { ((("<") ~ (Spacing)) ~ (TypeArgument) ~ (zeroOrMore(((",") ~ (Spacing)) ~ (TypeArgument))) ~ ((">") ~ (Spacing))) }
	TypeArgument = rule { ((ReferenceType) | ((("?") ~ (Spacing)) ~ (optional(((("extends") ~ (!(LetterOrDigit)) ~ (Spacing)) | (("super") ~ (!(LetterOrDigit)) ~ (Spacing))) ~ (ReferenceType))))) }
	TypeParameters = rule { ((("<") ~ (Spacing)) ~ (TypeParameter) ~ (zeroOrMore(((",") ~ (Spacing)) ~ (TypeParameter))) ~ ((">") ~ (Spacing))) }
	TypeParameter = rule { ((Identifier) ~ (optional((("extends") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Bound)))) }
	Bound = rule { ((ClassType) ~ (zeroOrMore((("&") ~ (!(anyOf("&="))) ~ (Spacing)) ~ (ClassType)))) }
	Modifier = rule { ((Annotation) | ((("public") | ("protected") | ("private") | ("static") | ("abstract") | ("final") | ("native") | ("synchronized") | ("transient") | ("volatile") | ("strictfp")) ~ (!(LetterOrDigit)) ~ (Spacing))) }
	AnnotationTypeDeclaration = rule { ((("@") ~ (Spacing)) ~ (("interface") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (Identifier) ~ (AnnotationTypeBody)) }
	AnnotationTypeBody = rule { ((("{") ~ (Spacing)) ~ (zeroOrMore(AnnotationTypeElementDeclaration)) ~ (("}") ~ (Spacing))) }
	AnnotationTypeElementDeclaration = rule { (((zeroOrMore(Modifier)) ~ (AnnotationTypeElementRest)) | ((";") ~ (Spacing))) }
	AnnotationTypeElementRest = rule { (((Type) ~ (AnnotationMethodOrConstantRest) ~ ((";") ~ (Spacing))) | (ClassDeclaration) | (EnumDeclaration) | (InterfaceDeclaration) | (AnnotationTypeDeclaration)) }
	AnnotationMethodOrConstantRest = rule { ((AnnotationMethodRest) | (AnnotationConstantRest)) }
	AnnotationMethodRest = rule { ((Identifier) ~ (("(") ~ (Spacing)) ~ ((")") ~ (Spacing)) ~ (optional(DefaultValue))) }
	AnnotationConstantRest = rule { (VariableDeclarators) }
	DefaultValue = rule { ((("default") ~ (!(LetterOrDigit)) ~ (Spacing)) ~ (ElementValue)) }
	Annotation = rule { ((("@") ~ (Spacing)) ~ (QualifiedIdentifier) ~ (optional(AnnotationRest))) }
	AnnotationRest = rule { ((NormalAnnotationRest) | (SingleElementAnnotationRest)) }
	NormalAnnotationRest = rule { ((("(") ~ (Spacing)) ~ (optional(ElementValuePairs)) ~ ((")") ~ (Spacing))) }
	ElementValuePairs = rule { ((ElementValuePair) ~ (zeroOrMore(((",") ~ (Spacing)) ~ (ElementValuePair)))) }
	ElementValuePair = rule { ((Identifier) ~ (("=") ~ (!("=")) ~ (Spacing)) ~ (ElementValue)) }
	ElementValue = rule { ((ConditionalExpression) | (Annotation) | (ElementValueArrayInitializer)) }
	ElementValueArrayInitializer = rule { ((("{") ~ (Spacing)) ~ (optional(ElementValues)) ~ (optional((",") ~ (Spacing))) ~ (("}") ~ (Spacing))) }
	ElementValues = rule { ((ElementValue) ~ (zeroOrMore(((",") ~ (Spacing)) ~ (ElementValue)))) }
	SingleElementAnnotationRest = rule { ((("(") ~ (Spacing)) ~ (ElementValue) ~ ((")") ~ (Spacing))) }
	Spacing = rule { (zeroOrMore((oneOrMore(anyOf("\t\n\f\r "))) | (("/*") ~ (zeroOrMore((!("*/")) ~ (anyOf("\u0000\u0001\u0002\u0003\u0004\u0005\u0006\u0007\b\t\n\u000b\f\r\u000e\u000f\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001a\u001b\u001c\u001d\u001e\u001f !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")))) ~ ("*/")) | (("//") ~ (zeroOrMore((!(anyOf("\n\r"))) ~ (anyOf("\u0000\u0001\u0002\u0003\u0004\u0005\u0006\u0007\b\t\n\u000b\f\r\u000e\u000f\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001a\u001b\u001c\u001d\u001e\u001f !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")))) ~ (optional(("\r\n") | ("\r") | ("\n")))))) }
	Identifier = rule { ((!(Keyword)) ~ (Letter) ~ (zeroOrMore(LetterOrDigit)) ~ (Spacing)) }
	Letter = rule { ((anyOf("abcdefghijklmnopqrstuvwxyz")) | (anyOf("ABCDEFGHIJKLMNOPQRSTUVWXYZ")) | ("_") | ("$")) }
	LetterOrDigit = rule { ((anyOf("abcdefghijklmnopqrstuvwxyz")) | (anyOf("ABCDEFGHIJKLMNOPQRSTUVWXYZ")) | (anyOf("0123456789")) | ("_") | ("$")) }
	Keyword = rule { ((("assert") | ("break") | ("case") | ("catch") | ("class") | ("const") | ("continue") | ("default") | ("do") | ("else") | ("enum") | ("extends") | ("finally") | ("final") | ("for") | ("goto") | ("if") | ("implements") | ("import") | ("interface") | ("instanceof") | ("new") | ("package") | ("return") | ("static") | ("super") | ("switch") | ("synchronized") | ("this") | ("throws") | ("throw") | ("try") | ("void") | ("while")) ~ (!(LetterOrDigit))) }
	Literal = rule { (((FloatLiteral) | (IntegerLiteral) | (CharLiteral) | (StringLiteral) | (("true") ~ (!(LetterOrDigit))) | (("false") ~ (!(LetterOrDigit))) | (("null") ~ (!(LetterOrDigit)))) ~ (Spacing)) }
	IntegerLiteral = rule { (((HexNumeral) | (OctalNumeral) | (DecimalNumeral)) ~ (optional(anyOf("Ll")))) }
	DecimalNumeral = rule { (("0") | ((anyOf("123456789")) ~ (zeroOrMore(Digit)))) }
	HexNumeral = rule { (("0") ~ (anyOf("Xx")) ~ (oneOrMore(HexDigit))) }
	HexDigit = rule { ((anyOf("abcdef")) | (anyOf("ABCDEF")) | (anyOf("0123456789"))) }
	OctalNumeral = rule { (("0") ~ (oneOrMore(anyOf("01234567")))) }
	FloatLiteral = rule { ((HexFloat) | (DecimalFloat)) }
	DecimalFloat = rule { (((oneOrMore(Digit)) ~ (".") ~ (zeroOrMore(Digit)) ~ (optional(Exponent)) ~ (optional(anyOf("DFdf")))) | ((".") ~ (oneOrMore(Digit)) ~ (optional(Exponent)) ~ (optional(anyOf("DFdf")))) | ((oneOrMore(Digit)) ~ (Exponent) ~ (optional(anyOf("DFdf")))) | ((oneOrMore(Digit)) ~ (optional(Exponent)) ~ (anyOf("DFdf")))) }
	Exponent = rule { ((anyOf("Ee")) ~ (optional(anyOf("+-"))) ~ (oneOrMore(Digit))) }
	Digit = rule { (anyOf("0123456789")) }
	HexFloat = rule { ((HexSignificant) ~ (BinaryExponent) ~ (optional(anyOf("DFdf")))) }
	HexSignificant = rule { (((("0x") | ("0X")) ~ (zeroOrMore(HexDigit)) ~ (".") ~ (oneOrMore(HexDigit))) | ((HexNumeral) ~ (optional(".")))) }
	BinaryExponent = rule { ((anyOf("Pp")) ~ (optional(anyOf("+-"))) ~ (oneOrMore(Digit))) }
	CharLiteral = rule { (("\'") ~ ((Escape) | ((!(anyOf("'\\"))) ~ (anyOf("\u0000\u0001\u0002\u0003\u0004\u0005\u0006\u0007\b\t\n\u000b\f\r\u000e\u000f\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001a\u001b\u001c\u001d\u001e\u001f !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")))) ~ ("\'")) }
	StringLiteral = rule { ((""") ~ (zeroOrMore((Escape) | ((!(anyOf("\n\r\"\\"))) ~ (anyOf("\u0000\u0001\u0002\u0003\u0004\u0005\u0006\u0007\b\t\n\u000b\f\r\u000e\u000f\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001a\u001b\u001c\u001d\u001e\u001f !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"))))) ~ (""")) }
	Escape = rule { (("\\") ~ ((anyOf("\"'\\bfnrt")) | (OctalEscape) | (UnicodeEscape))) }
	OctalEscape = rule { (((anyOf("0123")) ~ (anyOf("01234567")) ~ (anyOf("01234567"))) | ((anyOf("01234567")) ~ (anyOf("01234567"))) | (anyOf("01234567"))) }
	UnicodeEscape = rule { ((oneOrMore("u")) ~ (HexDigit) ~ (HexDigit) ~ (HexDigit) ~ (HexDigit)) }

