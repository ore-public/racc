j
<h1>Racc の使い方</h1>
<p>
Racc は文法規則から Ruby で書かれたパーサを生成するパーサジェネレータです。
パーサ生成アルゴリズムには yacc などと同じ LALR(1) を使用しています。
</p>
<p>
yacc を知っている人は記述法の違いだけわかれば使えると思います。
yacc を知らない人は
拙著『Ruby を 256 倍使うための本 無道編』(青木峰郎著、ASCII)
などを一読していただくのがよいかと思います。
他の UNIX コマンドなどとは異なり、
いきなり使うだけで Racc を理解するのはかなり困難です。
</p>

<h2>Racc とはなにか</h2>
<p>
Racc は文法を処理するツールです。
文字列はただの文字の列で、コンピュータにとっては意味を持ちません。
しかし人間はその文字の列の中になにか意味を見出すことができます。
コンピュータにもそのようなことを、部分的にでも、させられたら便利でしょう。
Racc はその手伝いをしてくれます。完全な自動化ではありませんが、
人間が全部やるよりも遥かに簡単になります。
</p>
<p>
Racc が自動化してくれる部分とは、文字列の含む「構造」の処理です。
たとえば Ruby の if 文を考えてみると、次のように定式化できます。
</p>
<pre>
if 条件式 [then]
  文
  ：
[elsif 条件式 [then]
  文
  ：]
[else
  文
  ：]
end
</pre>
<p>
if 文では if という単語が最初になくてはならず、
elsif 節は else 節より前になくてはいけません。
このような配置の関係 (構造) が、Racc が処理する対象です。
</p>
<p>
一方、Racc で処理できないのはどういうことでしょうか。それは、たとえば
if の条件式にあたる部分が「なんであるか」ということです。つまり、条件
式が if の条件だということです。これは、こっちで条件として扱うコードを
書いてやらないといけません。
</p>
<p>
と言っても、わかりにくいでしょう。こういう抽象的なものは実際にいじって
みるのが一番です。
</p>

<h2>実際の話</h2>
<p>
実際に Racc をどのように使うかという話をします。Racc には独自のソース
コードみたいなものがあって、この中に処理したい「構造」を記述しておきま
す。このソースファイルを「文法ファイル」と呼ぶことにしましょう。この文
法ファイルの名前が parse.y と仮定すると、コマンドラインから以下のよう
に打ちこめば、その構造を処理するためのクラスを含んだファイルが得られま
す。
</p>
<pre>
$ racc parse.y
</pre>
<p>
生成されるファイルはデフォルトでは "ファイル名.tab.rb" です。他の名前
にしたいなら、-o オプションで変更できます。
</p>
<pre>
$ racc parse.y -o myparser.rb
</pre>
<p>
このようにして作ったクラス、またはそのような処理を担当するパート、
のことはパーサ (parser) と呼ぶことになっています。解析するヤツ、
というくらいに適当にとらえてください。
</p>

<h2>文法ファイルを書く</h2>
<p>
Racc は文法ファイルから Ruby のクラスを生成するツールだと言いました。
そのクラスは全て Racc::Parser の下位クラスで、名前は文法ファイル中で
指定します。以下、ここに書くべきことが「なんなのか」を説明します。
ここでは内容に重点を置くので、文法ファイル自体の文法の詳細は
<a href="grammar.html">文法リファレンス</a>を見てください。
</p>

<h3>文法</h3>
<p>
まずは、全体の概形です。
</p>
<pre>
class MyParser
rule

  if_stmt: IF expr then stmt_list elsif else END

  then   : THEN
         |

  elsif  :
         | ELSIF stmt_list

  else   :
         | ELSE stmt_list

  expr   : NUMBER
         | IDENT
         | STRING

  stmt_list : ふにゃふにゃ

end
</pre>
<p>
Ruby スクリプトのように class でパーサクラス名を指定し、rule ... end 
の間にパーサに解析させたい文法を記述します。
</p>
<p>
文法は、記号の並びでもって表します。rule ... end の間にあるコロンとバー
以外のもの、if_stmt IF expr then などが全て「記号」です。そしてコロン
が日本語で言う「〜は××だ」の「は」みたいなもんで、その左の記号が右の
記号の列と同じものを指す、というふうに定義します。また、バーは「または」
を意味します。それと、単純にコロンの左の記号のことを左辺、右を右辺とも
言います。以下はこちらのほうを使って説明しましょう。
</p>
<p>
少し注意が必要な点を述べます。まず、then の、バーのあとの定義 (規則) を
見てください。ここには何も書いていないので、これはその通り「無」であっ
てもいい、ということを表しています。つまり、then は記号 THEN 一個か、
またはなにもなし(省略する)でよい、ということです。記号 then は実際の 
Ruby のソースコードにある then とは切り離して考えましょう
(それは実は大文字の記号 THEN が表しています)。
</p>
<p>
さて、そろそろ「記号」というものがなんなのか書きましょう。
ただし順番に話をしないといけないので、まずは聞いていてください。
この文章の最初に、パーサとは文字の列から構造を見出す部分だと言いました。
しかし文字の列からいきなり構造を探すのは面倒なので、実際にはまず
文字の列を単語の列に分割します。その時点でスペースやコメントは捨てて
しまい、以降は純粋にプログラムの一部をなす部分だけを相手にします。
たとえば文字列の入力が次のようだったとすると、
</p>
<pre>
if flag then   # item found.
  puts 'ok'
end
</pre>
<p>
単語の列は次のようになります。
</p>
<pre>
if flag then puts 'ok' end
</pre>
<p>
ここで、工夫が必要です。どうやら flag はローカル変数名だと思われますが、
変数名というのは他にもいろいろあります。しかし名前が i だろうが a だろ
うが vvvvvvvvvvvv だろうが、「構造」は同じです。つまり同じ扱いをされる
べきです。変数 a を書ける場所なら b も書けなくてはいけません。だったら
一時的に同じ名前で読んでもいいじゃん。ということで、この単語の列を以下
のように読みかえましょう。
</p>
<pre>
IF IDENT THEN IDENT STRING END
</pre>
<p>
これが「記号」の列です。パーサではこの記号列のほうを扱い、構造を見付け
ていきます。
</p>
<p>
さらに記号について見ていきましょう。
記号は二種類に分けられます。「左辺にある記号」と「ない記号」です。
左辺にある記号は「非終端」記号と言います。ないほうは「終端」記号と
言います。最初の例では終端記号はすべて大文字、非終端記号は小文字で
書いてあるので、もう一度戻って例の文法を見てください。
</p>
<p>
なぜこの区分が重要かと言うと、入力の記号列はすべて終端記号だからです。
一方、非終端記号はパーサの中でだけ、終端記号の列から「作りだす」ことに
よって始めて存在します。例えば次の規則をもう一度見てください。
</p>
<pre>
  expr   : NUMBER
         | IDENT
         | STRING
</pre>
<p>
expr は NUMBER か IDENT か STRING だと言っています。逆に言うと、
IDENT は expr に「なることができます」。文法上 expr が存在できる
場所に IDENT が来ると、それは expr になります。例えば if の条件式の
部分は expr ですから、ここに IDENT があると expr になります。その
ように文法的に「大きい」記号を作っていって、最終的に一個になると、
その入力は文法を満たしていることになります。実際にさっきの入力で
試してみましょう。入力はこうでした。
</p>
<pre>
IF IDENT THEN IDENT STRING END
</pre>
<p>
まず、IDENT が expr になります。
</p>
<pre>
IF expr THEN IDENT STRING END
</pre>
<p>
次に THEN が then になります。
</p>
<pre>
IF expr then IDENT STRING END
</pre>
<p>
IDENT STRING がメソッドコールになります。この定義はさきほどの例には
ないですが、実は省略されているんだと考えてください。そしていろいろな
過程を経て、最終的には stmt_list (文のリスト)になります。
</p>
<pre>
IF expr then stmt_list END
</pre>
<p>
elsif と else は省略できる、つまり無から生成できます。
</p>
<pre>
IF expr then stmt_list elsif else END
</pre>
<p>
最後に if_stmt を作ります。
</p>
<pre>
if_stmt
</pre>
<p>
ということでひとつになりました。
つまりこの入力は文法的に正しいということがわかりました。
</p>

<h3>アクション</h3>
<p>
ここまでで入力の文法が正しいかどうかを確認する方法はわかりましたが、
これだけではなんにもなりません。最初に説明したように、ここまででは
構造が見えただけで、プログラムは「意味」を理解できません。そしてその
部分は Racc では自動処理できないので、人間が書く、とも言いました。
それを書くのが以下に説明する「アクション」という部分です。
</p>
<p>
前項で、記号の列がだんだんと大きな単位にまとめられていく過程を見ました。
そのまとめる時に、同時になにかをやらせることができます。それが
アクションです。アクションは、文法ファイルで以下のように書きます。
</p>
<pre>
class MyParser
rule

  if_stmt: IF expr then stmt_list elsif else END
             { puts 'if_stmt found' }

  then   : THEN
             { puts 'then found' }
         |
             { puts 'then is omitted' }

  elsif  :
             { puts 'elsif is omitted' }
         | ELSIF stmt_list
             { puts 'elsif found' }

  else   :
             { puts 'else omitted' }
         | ELSE stmt_list
             { puts 'else found' }

  expr   : NUMBER
             { puts 'expr found (NUMBER)' }
         | IDENT
             { puts 'expr found (IDENT)' }
         | STRING
             { puts 'expr found (STRING)' }

  stmt_list : ふにゃふにゃ

end
</pre>
<p>
見てのとおり、規則のあとに { と } で囲んで書きます。
アクションにはだいたい好きなように Ruby スクリプトが書けます。
</p>
<p>
(この節、未完)
</p>
<hr>

<p>
yacc での <code>$$</code> は Racc ではローカル変数 <code>result</code>
で、<code>$1,$2...</code> は配列 <var>val</var>です。
<code>result</code> は <code>val[0]</code> ($1) の値に初期化され、
アクションを抜けたときの <code>result</code> の値が左辺値になります。
Racc ではアクション中の <code>return</code> はアクションから抜けるだけで、
パース自体は終わりません。アクション中からパースを終了するには、
メソッド <code>yyaccept</code> を使ってください。
</p>
<p>
演算子の優先順位、スタートルールなどの yacc の一般的な機能も用意されて
います。ただしこちらも少し文法が違います。
</p>
<p>
yacc では生成されたコードに直接転写されるコードがありました。
Racc でも同じように、ユーザ指定のコードが書けます。
Racc ではクラスを生成するので、クラス定義の前/中/後の三個所があります。
Racc ではそれを上から順番に header inner footer と呼んでいます。
</p>

<h3>ユーザが用意すべきコード</h3>
<p>
パースのエントリポイントとなるメソッドは二つあります。ひとつは 
<code>do_parse</code>で、こちらはトークンを 
<code>Parser#next_token</code> から得ます。もうひとつは 
<code>yyparse</code> で、こちらはスキャナから <code>yield</code> され
ることによってトークンを得ます。ユーザ側ではこのどちらか(両方でもいい
けど)を起動する簡単なメソッドを inner に書いてください。これらメソッド
の引数など、詳しいことはリファレンスを見てください。
</p>
<ul>
<li><a href="parser.html#Racc%3a%3aParser-do_parse">do_parse</a>
<li><a href="parser.html#Racc%3a%3aParser-yyparse">yyparse</a>
</ul>
<p>
どちらのメソッドにも共通なのはトークンの形式です。必ずトークンシンボル
とその値の二要素を持つ配列を返すようにします。またスキャンが終了して、
もう送るものがない場合は <code>[false,<var>なにか</var]</code> を返し
てください。これは一回返せば十分です (逆に、<code>yyparse</code> を使
う場合は二回以上 <code>yield</code> してはいけない)。
</p>
<p>
パーサは別に文字列処理にだけ使われるものではありませんが、実際問題とし
て、パーサを作る場面ではたいてい文字列のスキャナとセットで使うことが多
いでしょう。Ruby ならスキャナくらい楽勝で作れますが、高速なスキャナと
なると実は難しかったりします。そこで高速なスキャナを作成するためのライ
ブラリも作っています。詳しくは
<a href="#WritingScanner">「スキャナを作る」の項</a>を見てください。
</p>
<p>
Racc には error トークンを使ったエラー回復機能もあります。yacc の
<code>yyerror()</code> は Racc では
<a href="parser.html#Racc%3a%3aParser-on_error"><code>Racc::Parser#on_error</code></a>
で、エラーが起きたトークンとその値、値スタック、の三つの引数をとります。
<code>on_error</code> のデフォルトの実装は例外
<code>Racc::ParseError</code> を発生します。
</p>
<p>
ユーザがアクション中でパースエラーを発見した場合は、メソッド
<a href="parser.html#Racc%3a%3aParser-yyerror"><code>yyerror</code></a>
を呼べばパーサがエラー回復モードに入ります。
ただしこのとき <code>on_error</code>は呼ばれません。
</p>

<h3>パーサを生成する</h3>
<p>
これだけあればだいたい書けると思います。あとは、最初に示した方法で文法
ファイルを処理し、Ruby スクリプトを得ます。
</p>
<p>
うまくいけばいいのですが、大きいものだと最初からはうまくいかないでしょ
う。racc に -g オプションをつけてコンパイルし、@yydebug を true にする
とデバッグ用の出力が得られます。デバッグ出力はパーサの @racc_debug_out 
に出力されます(デフォルトは stderr)。また、racc に -v オプションをつけ
ると、状態遷移表を読みやすい形で出力したファイル(*.output)が得られます。
どちらもデバッグの参考になるでしょう。
</p>


<h2>作ったパーサを配布する</h2>
<p>
Racc の生成したパーサは動作時にランタイムルーチンが必要です。
具体的には parser.rb と cparse.so です。
ただし cparse.so は単にパースを高速化するためのライブラリなので
必須ではありません。なくても動きます。
</p>
<p>
まず Ruby 1.8.0 以降にはこのランタイムが標準添付されているので、
Ruby 1.8 がある環境ならばランタイムについて考慮する必要はありません。
Racc 1.4.x のランタイムと Ruby 1.8 に添付されているランタイムは
完全互換です。
</p>
<p>
問題は Ruby 1.8 を仮定できない場合です。 
Racc をユーザみんなにインストールしてもらうのも一つの手ですが、
これでは不親切です。そこでRacc では回避策を用意しました。
</p>
<p>
racc に -E オプションをつけてコンパイルすると、
パーサと racc/parser.rb を合体したファイルを出力できます。
これならばファイルは一つだけなので簡単に扱えます。
racc/parser.rb は擬似的に require したような扱いになるので、
この形式のパーサが複数あったとしてもクラスやメソッドが衝突することもありません。
ただし -E を使った場合は cparse.so が使えませんので、
必然的にパーサの速度は落ちます。
</p>


<h2><a name="WritingScanner">おまけ： スキャナを書く</a></h2>
<p>
パーサを使うときは、たいてい文字列をトークンに切りわけてくれるスキャナ
が必要になります。しかし実は Ruby は文字列の最初からトークンに切りわけ
ていくという作業があまり得意ではありません。
正確に言うと、簡単にできるのですが、それなりのオーバーヘッドがかかります。
</p>
<p>
そのオーバーヘッドを回避しつつ、
手軽にスキャナを作れるように strscan というパッケージを作りました。
Ruby 1.8 以降には標準添付されていますし、
<a href="http://i.loveruby.net/ja/">筆者のホームページ</a>には
単体パッケージがあります。
</p>
e
<h1>Usage</h1>

<h2>Generating Parser Using Racc</h2>
<p>
To compile Racc grammar file, simply type:
</p>
<pre>
$ racc parse.y
</pre>
<p>
This creates ruby script file "parse.tab.y". -o option changes this.
</p>

<h2>Writing Racc Grammer File</h2>
<p>
If you want your own parser, you have to write grammar file.
A grammar file contains name of parser class, grammar the parser can parse,
user code, and any.<br>
When writing grammar file, yacc's knowledge is helpful.
If you have not use yacc, also racc is too difficult.
</p>
<p>
Here's example of Racc grammar file.
</p>
<pre>
class Calcparser
rule
  target: exp { print val[0] }

  exp: exp '+' exp
     | exp '*' exp
     | '(' exp ')'
     | NUMBER
end
</pre>
<p>
Racc grammar file is resembles to yacc file.
But (of cource), action is Ruby code. yacc's $$ is 'result', $0, $1... is
an array 'val', $-1, $-2... is an array '_values'.
</p>
<p>
Then you must prepare parse entry method. There's two types of
racc's parse method, 
<a href="parser.html#Racc%3a%3aParser-do_parse"><code>do_parse</code></a> and
<a href="parser.html#Racc%3a%3aParser-yyparse"><code>yyparse</code></a>.
</p>
<p>
"do_parse()" is simple. it is yyparse() of yacc, and "next_token()" is
yylex(). This method must returns an array like [TOKENSYMBOL, ITS_VALUE].
EOF is [false, false].
(token symbol is ruby symbol (got by String#intern) as default.
 If you want to change this, see <a href="grammar.html#token">grammar reference</a>.
</p>
<p>
"yyparse()" is little complecated, but useful. It does not use "next_token()",
it gets tokens from any iterator. For example, "yyparse(obj, :scan)" causes
calling obj#scan, and you can return tokens by yielding them from obj#scan.
</p>
<p>
When debugging, "-v" or/and "-g" option is helpful.
"-v" causes creating verbose log file (.output).
"-g" causes creating "Verbose Parser".
Verbose Parser prints internal status when parsing.
But it is <em>not</em> automatic.
You must use -g option and set @yydebug true to get output.
-g option only creates verbose parser.
</p>

<h3>re-distributing Racc runtime</h3>
<p>
A parser, which is created by Racc, requires Racc runtime module;
racc/parser.rb.
</p>
<p>
Ruby 1.8.x comes with racc runtime module,
you need NOT distribute racc runtime files.
</p>
<p>
If you want to run your parsers on ruby 1.6,
you need re-distribute racc runtime module with your parser.
It can be done by using '-E' option:
<pre>
$ racc -E -omyparser.rb myparser.y
</pre>
<p>
This command creates myparser.rb which `includes' racc runtime.
Only you must do is to distribute your parser file (myparser.rb).
</p>
<p>
Note: parser.rb is LGPL, but your parser is not.
Your own parser is completely yours.
</p>
.
