#define list multiset
#define perror(X) werror(X)
#define efun predef
#if constant(_static_modules)
#define regexp(X, Y)	filter((X), Regexp(Y)->match)
#endif
