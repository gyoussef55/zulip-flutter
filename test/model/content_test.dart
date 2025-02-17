import 'dart:io';

import 'package:checks/checks.dart';
import 'package:html/parser.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:test/scaffolding.dart';
import 'package:zulip/model/code_block.dart';
import 'package:zulip/model/content.dart';

import 'content_checks.dart';

/// An example of Zulip content for test cases.
//
// When writing examples:
//
//  * Try to use actual HTML emitted by a Zulip server for [html].
//    Record the corresponding Markdown source in [markdown].
//
//  * Here's a handy `curl` command for getting the server's HTML.
//    First, as one-time setup, create a file with a test account's
//    Zulip credentials in "netrc" format, meaning one line that looks like:
//       machine HOSTNAME login EMAIL password API_KEY
//
//  * Then send some test messages, and fetch with a command like this.
//    (Change "sender" operand to your user ID, and "topic" etc. as desired.)
/*    $ curl -sS --netrc-file ../.netrc -G https://chat.zulip.org/api/v1/messages \
          --data-urlencode 'narrow=[{"operator":"sender", "operand":2187},
                                    {"operator":"stream", "operand":"test here"},
                                    {"operator":"topic",  "operand":"content"}]' \
          --data-urlencode anchor=newest --data-urlencode num_before=10 --data-urlencode num_after=0 \
          --data-urlencode apply_markdown=true \
        | jq '.messages[] | .content'
 */
//
//  * To get the corresponding Markdown source, use the same command
//    with `apply_markdown` changed to `false`.
class ContentExample {
  const ContentExample(this.description, this.markdown, this.html,
    this.expectedNodes, {this.expectedText});

  ContentExample.inline(this.description, this.markdown, this.html,
      InlineContentNode parsed, {this.expectedText})
    : expectedNodes = [ParagraphNode(links: null, nodes: [parsed])];

  /// A description string, for use in names of tests.
  final String description;

  /// The Zulip Markdown source, if any, that the server renders as [html].
  ///
  /// This is useful for reproducing the example content for live use in the
  /// app, and as a starting point for variations on it.
  ///
  /// Currently the test suite does not verify the relationship between
  /// [markdown] and [html].
  ///
  /// If there is no known Markdown that a Zulip server can render as [html],
  /// then this should be null and a comment should explain why the test uses
  /// such an example.
  final String? markdown;

  /// A fragment of Zulip HTML, to be parsed as a [ZulipContent].
  ///
  /// Generally this should be actual HTML emitted by a Zulip server.
  /// See the example `curl` command in comments on this class for help in
  /// conveniently getting such HTML.
  final String html;

  /// The [ZulipContent.nodes] expected from parsing [html].
  final List<BlockContentNode> expectedNodes;

  /// The text, if applicable, of a text widget expected from
  /// rendering [expectedNodes].
  ///
  /// Strictly this belongs to the widget tests, not the model tests, as it
  /// encodes choices about how the content widgets work.  But it's convenient
  /// to have it defined for each test case right next to [html] and [expectedNodes].
  final String? expectedText;

  static final emojiUnicode = ContentExample.inline(
    'Unicode emoji, encoded in span element',
    ":thumbs_up:",
    expectedText: '\u{1f44d}', // "👍"
    '<p><span aria-label="thumbs up" class="emoji emoji-1f44d" role="img" title="thumbs up">:thumbs_up:</span></p>',
    const UnicodeEmojiNode(emojiUnicode: '\u{1f44d}'));

  static final emojiUnicodeClassesFlipped = ContentExample.inline(
    'Unicode emoji, encoded in span element, class order reversed',
    null, // ":thumbs_up:" (hypothetical server variation)
    expectedText: '\u{1f44d}', // "👍"
    '<p><span aria-label="thumbs up" class="emoji-1f44d emoji" role="img" title="thumbs up">:thumbs_up:</span></p>',
    const UnicodeEmojiNode(emojiUnicode: '\u{1f44d}'));

  static final emojiUnicodeMultiCodepoint = ContentExample.inline(
    'Unicode emoji, encoded in span element, multiple codepoints',
    ":transgender_flag:",
    expectedText: '\u{1f3f3}\u{fe0f}\u{200d}\u{26a7}\u{fe0f}', // "🏳️‍⚧️"
    '<p><span aria-label="transgender flag" class="emoji emoji-1f3f3-fe0f-200d-26a7-fe0f" role="img" title="transgender flag">:transgender_flag:</span></p>',
    const UnicodeEmojiNode(emojiUnicode: '\u{1f3f3}\u{fe0f}\u{200d}\u{26a7}\u{fe0f}'));

  static final emojiUnicodeLiteral = ContentExample.inline(
    'Unicode emoji, not encoded in span element',
    "\u{1fabf}",
    expectedText: '\u{1fabf}', // "🪿"
    '<p>\u{1fabf}</p>',
    const TextNode('\u{1fabf}'));

  static final emojiCustom = ContentExample.inline(
    'custom emoji',
    ":flutter:",
    '<p><img alt=":flutter:" class="emoji" src="/user_avatars/2/emoji/images/204.png" title="flutter"></p>',
    const ImageEmojiNode(
      src: '/user_avatars/2/emoji/images/204.png', alt: ':flutter:'));

  static final emojiCustomInvalidUrl = ContentExample.inline(
    'custom emoji with invalid URL',
    null, // hypothetical, to test for a risk of crashing
    '<p><img alt=":invalid:" class="emoji" src="::not a URL::" title="invalid"></p>',
    const ImageEmojiNode(
      src: '::not a URL::', alt: ':invalid:'));

  static final emojiZulipExtra = ContentExample.inline(
    'Zulip extra emoji',
    ":zulip:",
    '<p><img alt=":zulip:" class="emoji" src="/static/generated/emoji/images/emoji/unicode/zulip.png" title="zulip"></p>',
    const ImageEmojiNode(
      src: '/static/generated/emoji/images/emoji/unicode/zulip.png', alt: ':zulip:'));

  static const quotation = ContentExample(
    'quotation',
    "```quote\nwords\n```",
    expectedText: 'words',
    '<blockquote>\n<p>words</p>\n</blockquote>', [
      QuotationNode([ParagraphNode(links: null, nodes: [TextNode('words')])])
    ]);

  static const codeBlockPlain = ContentExample(
    'code block without syntax highlighting',
    "```\nverb\natim\n```",
    expectedText: 'verb\natim',
    '<div class="codehilite"><pre><span></span><code>verb\natim\n</code></pre></div>', [
      CodeBlockNode([
        CodeBlockSpanNode(text: 'verb\natim', type: CodeBlockSpanType.text),
      ]),
    ]);

  static const codeBlockHighlightedShort = ContentExample(
    'code block with syntax highlighting',
    "```dart\nclass A {}\n```",
    expectedText: 'class A {}',
    '<div class="codehilite" data-code-language="Dart"><pre>'
        '<span></span><code><span class="kd">class</span><span class="w"> </span>'
        '<span class="nc">A</span><span class="w"> </span><span class="p">{}</span>'
        '\n</code></pre></div>', [
      CodeBlockNode([
        CodeBlockSpanNode(text: 'class', type: CodeBlockSpanType.keywordDeclaration),
        CodeBlockSpanNode(text: ' ', type: CodeBlockSpanType.whitespace),
        CodeBlockSpanNode(text: 'A', type: CodeBlockSpanType.nameClass),
        CodeBlockSpanNode(text: ' ', type: CodeBlockSpanType.whitespace),
        CodeBlockSpanNode(text: '{}', type: CodeBlockSpanType.punctuation),
      ]),
    ]);

  static const codeBlockHighlightedMultiline = ContentExample(
    'code block, multiline, with syntax highlighting',
    '```rust\nfn main() {\n    print!("Hello ");\n\n    print!("world!\\n");\n}\n```',
    expectedText: 'fn main() {\n    print!("Hello ");\n\n    print!("world!\\n");\n}',
    '<div class="codehilite" data-code-language="Rust"><pre>'
        '<span></span><code><span class="k">fn</span> <span class="nf">main</span>'
        '<span class="p">()</span><span class="w"> </span><span class="p">{</span>\n'
        '<span class="w">    </span><span class="fm">print!</span><span class="p">(</span>'
        '<span class="s">"Hello "</span><span class="p">);</span>\n\n'
        '<span class="w">    </span><span class="fm">print!</span><span class="p">(</span>'
        '<span class="s">"world!</span><span class="se">\\n</span><span class="s">"</span>'
        '<span class="p">);</span>\n<span class="p">}</span>\n'
        '</code></pre></div>', [
      CodeBlockNode([
        CodeBlockSpanNode(text: 'fn', type: CodeBlockSpanType.keyword),
        CodeBlockSpanNode(text: ' ', type: CodeBlockSpanType.text),
        CodeBlockSpanNode(text: 'main', type: CodeBlockSpanType.nameFunction),
        CodeBlockSpanNode(text: '()', type: CodeBlockSpanType.punctuation),
        CodeBlockSpanNode(text: ' ', type: CodeBlockSpanType.whitespace),
        CodeBlockSpanNode(text: '{', type: CodeBlockSpanType.punctuation),
        CodeBlockSpanNode(text: '\n', type: CodeBlockSpanType.text),
        CodeBlockSpanNode(text: '    ', type: CodeBlockSpanType.whitespace),
        CodeBlockSpanNode(text: 'print!', type: CodeBlockSpanType.nameFunctionMagic),
        CodeBlockSpanNode(text: '(', type: CodeBlockSpanType.punctuation),
        CodeBlockSpanNode(text: '"Hello "', type: CodeBlockSpanType.string),
        CodeBlockSpanNode(text: ');', type: CodeBlockSpanType.punctuation),
        CodeBlockSpanNode(text: '\n\n', type: CodeBlockSpanType.text),
        CodeBlockSpanNode(text: '    ', type: CodeBlockSpanType.whitespace),
        CodeBlockSpanNode(text: 'print!', type: CodeBlockSpanType.nameFunctionMagic),
        CodeBlockSpanNode(text: '(', type: CodeBlockSpanType.punctuation),
        CodeBlockSpanNode(text: '"world!', type: CodeBlockSpanType.string),
        CodeBlockSpanNode(text: '\\n', type: CodeBlockSpanType.stringEscape),
        CodeBlockSpanNode(text: '"', type: CodeBlockSpanType.string),
        CodeBlockSpanNode(text: ');', type: CodeBlockSpanType.punctuation),
        CodeBlockSpanNode(text: '\n', type: CodeBlockSpanType.text),
        CodeBlockSpanNode(text: '}', type: CodeBlockSpanType.punctuation),
      ]),
    ]);

  static final codeBlockWithHighlightedLines = ContentExample(
    'code block, with syntax highlighting and highlighted lines',
    '```\n::markdown hl_lines="2 4"\n# he\n## llo\n### world\n```',
    '<div class="codehilite"><pre>'
        '<span></span><code>::markdown hl_lines=&quot;2 4&quot;\n'
        '<span class="hll"><span class="gh"># he</span>\n'
        '</span><span class="gu">## llo</span>\n'
        '<span class="hll"><span class="gu">### world</span>\n'
        '</span></code></pre></div>', [
      // TODO: Fix this, see comment under `CodeBlockSpanType.highlightedLines` case in lib/model/content.dart.
      blockUnimplemented('<div class="codehilite"><pre>'
        '<span></span><code>::markdown hl_lines=&quot;2 4&quot;\n'
        '<span class="hll"><span class="gh"># he</span>\n'
        '</span><span class="gu">## llo</span>\n'
        '<span class="hll"><span class="gu">### world</span>\n'
        '</span></code></pre></div>'),
    ]);

  static final codeBlockWithUnknownSpanType = ContentExample(
    'code block, with an unknown span type',
    null, // this test is for future Pygments versions adding new token types
    '<div class="codehilite" data-code-language="Dart"><pre>'
        '<span></span><code><span class="unknown">class</span>'
        '\n</code></pre></div>', [
      blockUnimplemented('<div class="codehilite" data-code-language="Dart"><pre>'
        '<span></span><code><span class="unknown">class</span>'
        '\n</code></pre></div>'),
    ]);

  static final mathInline = ContentExample.inline(
    'inline math',
    r"$$ \lambda $$",
    expectedText: r'\lambda',
    '<p><span class="katex">'
      '<span class="katex-mathml"><math xmlns="http://www.w3.org/1998/Math/MathML"><semantics><mrow><mi>λ</mi></mrow>'
        '<annotation encoding="application/x-tex"> \\lambda </annotation></semantics></math></span>'
      '<span class="katex-html" aria-hidden="true"><span class="base"><span class="strut" style="height:0.6944em;"></span><span class="mord mathnormal">λ</span></span></span></span></p>',
    const MathInlineNode(texSource: r'\lambda'));

  static const mathBlock = ContentExample(
    'math block',
    "```math\n\\lambda\n```",
    expectedText: r'\lambda',
    '<p><span class="katex-display"><span class="katex">'
      '<span class="katex-mathml"><math xmlns="http://www.w3.org/1998/Math/MathML" display="block"><semantics><mrow><mi>λ</mi></mrow>'
        '<annotation encoding="application/x-tex">\\lambda</annotation></semantics></math></span>'
      '<span class="katex-html" aria-hidden="true"><span class="base"><span class="strut" style="height:0.6944em;"></span><span class="mord mathnormal">λ</span></span></span></span></span></p>',
    [MathBlockNode(texSource: r'\lambda')]);

  static const mathBlockInQuote = ContentExample(
    'math block in quote',
    // There's sometimes a quirky extra `<br>\n` at the end of the `<p>` that
    // encloses the math block.  In particular this happens when the math block
    // is the last thing in the quote; though not in a doubly-nested quote;
    // and there might be further wrinkles yet to be found.  Some experiments:
    //   https://chat.zulip.org/#narrow/stream/7-test-here/topic/content/near/1715732
    "````quote\n```math\n\\lambda\n```\n````",
    '<blockquote>\n<p>'
      '<span class="katex-display"><span class="katex">'
        '<span class="katex-mathml"><math xmlns="http://www.w3.org/1998/Math/MathML" display="block"><semantics><mrow><mi>λ</mi></mrow>'
          '<annotation encoding="application/x-tex">\\lambda</annotation></semantics></math></span>'
        '<span class="katex-html" aria-hidden="true"><span class="base"><span class="strut" style="height:0.6944em;"></span><span class="mord mathnormal">λ</span></span></span></span></span>'
      '<br>\n</p>\n</blockquote>',
    [QuotationNode([MathBlockNode(texSource: r'\lambda')])]);

  static const imageSingle = ContentExample(
    'single image',
    "https://chat.zulip.org/user_avatars/2/realm/icon.png?version=3",
    '<div class="message_inline_image">'
      '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png?version=3">'
        '<img src="https://chat.zulip.org/user_avatars/2/realm/icon.png?version=3"></a></div>', [
    ImageNodeList([
      ImageNode(srcUrl: 'https://chat.zulip.org/user_avatars/2/realm/icon.png?version=3'),
    ]),
  ]);

  static const imageInvalidUrl = ContentExample(
    'single image with invalid URL',
    null, // hypothetical, to test for a risk of crashing
    '<div class="message_inline_image">'
      '<a href="::not a URL::">'
        '<img src="::not a URL::"></a></div>', [
    ImageNodeList([
      ImageNode(srcUrl: '::not a URL::'),
    ]),
  ]);

  static const imageCluster = ContentExample(
    'multiple images',
    "https://chat.zulip.org/user_avatars/2/realm/icon.png?version=3\nhttps://chat.zulip.org/user_avatars/2/realm/icon.png?version=4",
    '<p>'
      '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png?version=3">https://chat.zulip.org/user_avatars/2/realm/icon.png?version=3</a><br>\n'
      '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png?version=4">https://chat.zulip.org/user_avatars/2/realm/icon.png?version=4</a></p>\n'
    '<div class="message_inline_image">'
      '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png?version=3">'
        '<img src="https://uploads.zulipusercontent.net/f535ba07f95b99a83aa48e44fd62bbb6c6cf6615/68747470733a2f2f636861742e7a756c69702e6f72672f757365725f617661746172732f322f7265616c6d2f69636f6e2e706e673f76657273696f6e3d33"></a></div>'
    '<div class="message_inline_image">'
      '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png?version=4">'
        '<img src="https://uploads.zulipusercontent.net/8f63bc2632a0e41be3f457d86c077e61b4a03e7e/68747470733a2f2f636861742e7a756c69702e6f72672f757365725f617661746172732f322f7265616c6d2f69636f6e2e706e673f76657273696f6e3d34"></a></div>', [
    ParagraphNode(links: null, nodes: [
      LinkNode(url: 'https://chat.zulip.org/user_avatars/2/realm/icon.png?version=3', nodes: [TextNode('https://chat.zulip.org/user_avatars/2/realm/icon.png?version=3')]),
      LineBreakInlineNode(),
      TextNode('\n'),
      LinkNode(url: 'https://chat.zulip.org/user_avatars/2/realm/icon.png?version=4', nodes: [TextNode('https://chat.zulip.org/user_avatars/2/realm/icon.png?version=4')]),
    ]),
    ImageNodeList([
      ImageNode(srcUrl: 'https://uploads.zulipusercontent.net/f535ba07f95b99a83aa48e44fd62bbb6c6cf6615/68747470733a2f2f636861742e7a756c69702e6f72672f757365725f617661746172732f322f7265616c6d2f69636f6e2e706e673f76657273696f6e3d33'),
      ImageNode(srcUrl: 'https://uploads.zulipusercontent.net/8f63bc2632a0e41be3f457d86c077e61b4a03e7e/68747470733a2f2f636861742e7a756c69702e6f72672f757365725f617661746172732f322f7265616c6d2f69636f6e2e706e673f76657273696f6e3d34'),
    ]),
  ]);

  static const imageClusterThenContent = ContentExample(
    'content after image cluster',
    "https://chat.zulip.org/user_avatars/2/realm/icon.png\nhttps://chat.zulip.org/user_avatars/2/realm/icon.png?version=2\n\nmore content",
    '<p>content '
      '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png">icon.png</a> '
      '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png?version=2">icon.png</a></p>\n'
    '<div class="message_inline_image">'
      '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png" title="icon.png">'
        '<img src="https://chat.zulip.org/user_avatars/2/realm/icon.png"></a></div>'
    '<div class="message_inline_image">'
      '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png?version=2" title="icon.png">'
        '<img src="https://chat.zulip.org/user_avatars/2/realm/icon.png?version=2"></a></div>'
    '<p>more content</p>', [
    ParagraphNode(links: null, nodes: [
      TextNode('content '),
      LinkNode(url: 'https://chat.zulip.org/user_avatars/2/realm/icon.png', nodes: [TextNode('icon.png')]),
      TextNode(' '),
      LinkNode(url: 'https://chat.zulip.org/user_avatars/2/realm/icon.png?version=2', nodes: [TextNode('icon.png')]),
    ]),
    ImageNodeList([
      ImageNode(srcUrl: 'https://chat.zulip.org/user_avatars/2/realm/icon.png'),
      ImageNode(srcUrl: 'https://chat.zulip.org/user_avatars/2/realm/icon.png?version=2'),
    ]),
    ParagraphNode(links: null, nodes: [
      TextNode('more content'),
    ]),
  ]);

  static const imageMultipleClusters = ContentExample(
    'multiple clusters of images',
    "https://en.wikipedia.org/static/images/icons/wikipedia.png\nhttps://en.wikipedia.org/static/images/icons/wikipedia.png?v=1\n\nTest\n\nhttps://en.wikipedia.org/static/images/icons/wikipedia.png?v=2\nhttps://en.wikipedia.org/static/images/icons/wikipedia.png?v=3",
    '<p>'
      '<a href="https://en.wikipedia.org/static/images/icons/wikipedia.png">https://en.wikipedia.org/static/images/icons/wikipedia.png</a><br>\n' '<a href="https://en.wikipedia.org/static/images/icons/wikipedia.png?v=1">https://en.wikipedia.org/static/images/icons/wikipedia.png?v=1</a></p>\n'
    '<div class="message_inline_image">'
      '<a href="https://en.wikipedia.org/static/images/icons/wikipedia.png">'
        '<img src="https://uploads.zulipusercontent.net/34b2695ca83af76204b0b25a8f2019ee35ec38fa/68747470733a2f2f656e2e77696b6970656469612e6f72672f7374617469632f696d616765732f69636f6e732f77696b6970656469612e706e67"></a></div>'
    '<div class="message_inline_image">'
      '<a href="https://en.wikipedia.org/static/images/icons/wikipedia.png?v=1">'
        '<img src="https://uploads.zulipusercontent.net/d200fb112aaccbff9df767373a201fa59601f362/68747470733a2f2f656e2e77696b6970656469612e6f72672f7374617469632f696d616765732f69636f6e732f77696b6970656469612e706e673f763d31"></a></div>'
    '<p>Test</p>\n'
    '<p>'
      '<a href="https://en.wikipedia.org/static/images/icons/wikipedia.png?v=2">https://en.wikipedia.org/static/images/icons/wikipedia.png?v=2</a><br>\n'
      '<a href="https://en.wikipedia.org/static/images/icons/wikipedia.png?v=3">https://en.wikipedia.org/static/images/icons/wikipedia.png?v=3</a></p>\n'
    '<div class="message_inline_image">'
      '<a href="https://en.wikipedia.org/static/images/icons/wikipedia.png?v=2">'
        '<img src="https://uploads.zulipusercontent.net/c4db87e81348dac94eacaa966b46d968b34029cc/68747470733a2f2f656e2e77696b6970656469612e6f72672f7374617469632f696d616765732f69636f6e732f77696b6970656469612e706e673f763d32"></a></div>'
    '<div class="message_inline_image">'
      '<a href="https://en.wikipedia.org/static/images/icons/wikipedia.png?v=3">'
        '<img src="https://uploads.zulipusercontent.net/51b70540cf6a5b3c8a0b919c893b8abddd447e88/68747470733a2f2f656e2e77696b6970656469612e6f72672f7374617469632f696d616765732f69636f6e732f77696b6970656469612e706e673f763d33"></a></div>', [
    ParagraphNode(links: null, nodes: [
      LinkNode(url: 'https://en.wikipedia.org/static/images/icons/wikipedia.png', nodes: [TextNode('https://en.wikipedia.org/static/images/icons/wikipedia.png')]),
      LineBreakInlineNode(),
      TextNode('\n'),
      LinkNode(url: 'https://en.wikipedia.org/static/images/icons/wikipedia.png?v=1', nodes: [TextNode('https://en.wikipedia.org/static/images/icons/wikipedia.png?v=1')]),
    ]),
    ImageNodeList([
      ImageNode(srcUrl: 'https://uploads.zulipusercontent.net/34b2695ca83af76204b0b25a8f2019ee35ec38fa/68747470733a2f2f656e2e77696b6970656469612e6f72672f7374617469632f696d616765732f69636f6e732f77696b6970656469612e706e67'),
      ImageNode(srcUrl: 'https://uploads.zulipusercontent.net/d200fb112aaccbff9df767373a201fa59601f362/68747470733a2f2f656e2e77696b6970656469612e6f72672f7374617469632f696d616765732f69636f6e732f77696b6970656469612e706e673f763d31'),
    ]),
    ParagraphNode(links: null, nodes: [
      TextNode('Test'),
    ]),
    ParagraphNode(links: null, nodes: [
      LinkNode(url: 'https://en.wikipedia.org/static/images/icons/wikipedia.png?v=2', nodes: [TextNode('https://en.wikipedia.org/static/images/icons/wikipedia.png?v=2')]),
      LineBreakInlineNode(),
      TextNode('\n'),
      LinkNode(url: 'https://en.wikipedia.org/static/images/icons/wikipedia.png?v=3', nodes: [TextNode('https://en.wikipedia.org/static/images/icons/wikipedia.png?v=3')]),
    ]),
    ImageNodeList([
      ImageNode(srcUrl: 'https://uploads.zulipusercontent.net/c4db87e81348dac94eacaa966b46d968b34029cc/68747470733a2f2f656e2e77696b6970656469612e6f72672f7374617469632f696d616765732f69636f6e732f77696b6970656469612e706e673f763d32'),
      ImageNode(srcUrl: 'https://uploads.zulipusercontent.net/51b70540cf6a5b3c8a0b919c893b8abddd447e88/68747470733a2f2f656e2e77696b6970656469612e6f72672f7374617469632f696d616765732f69636f6e732f77696b6970656469612e706e673f763d33'),
    ]),
  ]);

  static const imageInImplicitParagraph = ContentExample(
    'image as immediate child in implicit paragraph',
    "* https://chat.zulip.org/user_avatars/2/realm/icon.png",
    '<ul>\n'
      '<li>'
        '<div class="message_inline_image">'
          '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png">'
            '<img src="https://chat.zulip.org/user_avatars/2/realm/icon.png"></a></div></li>\n</ul>', [
    ListNode(ListStyle.unordered, [[
      ImageNodeList([
        ImageNode(srcUrl: 'https://chat.zulip.org/user_avatars/2/realm/icon.png'),
      ]),
    ]]),
  ]);

  static const imageClusterInImplicitParagraph = ContentExample(
    'image cluster in implicit paragraph',
    "* [icon.png](https://chat.zulip.org/user_avatars/2/realm/icon.png) [icon.png](https://chat.zulip.org/user_avatars/2/realm/icon.png?version=2)",
    '<ul>\n'
      '<li>'
        '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png">icon.png</a> '
        '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png?version=2">icon.png</a>'
        '<div class="message_inline_image">'
          '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png" title="icon.png">'
            '<img src="https://chat.zulip.org/user_avatars/2/realm/icon.png"></a></div>'
        '<div class="message_inline_image">'
          '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png?version=2" title="icon.png">'
            '<img src="https://chat.zulip.org/user_avatars/2/realm/icon.png?version=2"></a></div></li>\n</ul>', [
    ListNode(ListStyle.unordered, [[
      ParagraphNode(wasImplicit: true, links: null, nodes: [
        LinkNode(url: 'https://chat.zulip.org/user_avatars/2/realm/icon.png', nodes: [TextNode('icon.png')]),
        TextNode(' '),
        LinkNode(url: 'https://chat.zulip.org/user_avatars/2/realm/icon.png?version=2', nodes: [TextNode('icon.png')]),
      ]),
      ImageNodeList([
        ImageNode(srcUrl: 'https://chat.zulip.org/user_avatars/2/realm/icon.png'),
        ImageNode(srcUrl: 'https://chat.zulip.org/user_avatars/2/realm/icon.png?version=2'),
      ]),
    ]]),
  ]);

  static final imageClusterInImplicitParagraphThenContent = ContentExample(
    'impossible content after image cluster in implicit paragraph',
    // Image previews are always inserted at the end of the paragraph
    //  so it would be impossible to have content after.
    null,
    '<ul>\n'
      '<li>'
        '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png">icon.png</a> '
        '<div class="message_inline_image">'
          '<a href="https://chat.zulip.org/user_avatars/2/realm/icon.png" title="icon.png">'
            '<img src="https://chat.zulip.org/user_avatars/2/realm/icon.png"></a></div>'
        'more text</li>\n</ul>', [
    ListNode(ListStyle.unordered, [[
      const ParagraphNode(wasImplicit: true, links: null, nodes: [
        LinkNode(url: 'https://chat.zulip.org/user_avatars/2/realm/icon.png', nodes: [TextNode('icon.png')]),
        TextNode(' '),
      ]),
      const ImageNodeList([
        ImageNode(srcUrl: 'https://chat.zulip.org/user_avatars/2/realm/icon.png'),
      ]),
      blockUnimplemented('more text'),
    ]]),
  ]);
}

UnimplementedBlockContentNode blockUnimplemented(String html) {
  var fragment = HtmlParser(html, parseMeta: false).parseFragment();
  return UnimplementedBlockContentNode(htmlNode: fragment.nodes.single);
}

UnimplementedInlineContentNode inlineUnimplemented(String html) {
  var fragment = HtmlParser(html, parseMeta: false).parseFragment();
  return UnimplementedInlineContentNode(htmlNode: fragment.nodes.single);
}

void testParse(String name, String html, List<BlockContentNode> nodes) {
  test(name, () {
    check(parseContent(html))
      .equalsNode(ZulipContent(nodes: nodes));
  });
}

void testParseExample(ContentExample example) {
  testParse('parse ${example.description}', example.html, example.expectedNodes);
}

void main() {
  // When writing test cases in this file:
  //
  //  * Prefer to add a [ContentExample] static and use [testParseExample].
  //    Then add one line of code to `test/widgets/content_test.dart`,
  //    calling `testContentSmoke`, for a widgets test on the same example.
  //
  //  * To write the example, see comment at top of [ContentExample].

  //
  // Inline content.
  //

  void testParseInline(String name, String html, InlineContentNode node) {
    testParse(name, html, [ParagraphNode(links: null, nodes: [node])]);
  }

  testParse('parse a plain-text paragraph',
    // "hello world"
    '<p>hello world</p>', const [ParagraphNode(links: null, nodes: [
      TextNode('hello world'),
    ])]);

  testParse('parse <br> inside a paragraph',
    // "a\nb"
    '<p>a<br>\nb</p>', const [ParagraphNode(links: null, nodes: [
      TextNode('a'),
      LineBreakInlineNode(),
      TextNode('\nb'),
    ])]);

  testParseInline('parse strong/bold',
    // "**bold**"
    '<p><strong>bold</strong></p>',
    const StrongNode(nodes: [TextNode('bold')]));

  testParseInline('parse emphasis/italic',
    // "*italic*"
    '<p><em>italic</em></p>',
    const EmphasisNode(nodes: [TextNode('italic')]));

  testParseInline('parse inline code',
    // "`inline code`"
    '<p><code>inline code</code></p>',
    const InlineCodeNode(nodes: [TextNode('inline code')]));

  testParseInline('parse nested strong, em, code',
    // "***`word`***"
    '<p><strong><em><code>word</code></em></strong></p>',
    const StrongNode(nodes: [EmphasisNode(nodes: [InlineCodeNode(nodes: [
      TextNode('word')])])]));

  group('LinkNode', () {
    testParseInline('parse link',
      // "[text](https://example/)"
      '<p><a href="https://example/">text</a></p>',
      const LinkNode(url: 'https://example/', nodes: [TextNode('text')]));

    testParseInline('parse #-mention of stream',
      // "#**general**"
      '<p><a class="stream" data-stream-id="2" href="/#narrow/stream/2-general">'
          '#general</a></p>',
      const LinkNode(url: '/#narrow/stream/2-general',
        nodes: [TextNode('#general')]));

    testParseInline('parse #-mention of topic',
      // "#**mobile-team>zulip-flutter**"
      '<p><a class="stream-topic" data-stream-id="243" '
          'href="/#narrow/stream/243-mobile-team/topic/zulip-flutter">'
          '#mobile-team &gt; zulip-flutter</a></p>',
      const LinkNode(url: '/#narrow/stream/243-mobile-team/topic/zulip-flutter',
        nodes: [TextNode('#mobile-team > zulip-flutter')]));
  });

  testParseInline('parse nested link, strong, em, code',
    // "[***`word`***](https://example/)"
    '<p><a href="https://example/"><strong><em><code>word'
        '</code></em></strong></a></p>',
    const LinkNode(url: 'https://example/',
      nodes: [StrongNode(nodes: [EmphasisNode(nodes: [InlineCodeNode(nodes: [
        TextNode('word')])])])]));

  testParseInline('parse nested strong, em, link',
    // "***[t](/u)***"
    '<p><strong><em><a href="/u">t</a></em></strong></p>',
    const StrongNode(nodes: [EmphasisNode(nodes: [LinkNode(url: '/u',
      nodes: [TextNode('t')])])]));

  group('parse @-mentions', () {
    testParseInline('plain user @-mention',
      // "@**Greg Price**"
      '<p><span class="user-mention" data-user-id="2187">@Greg Price</span></p>',
      const UserMentionNode(nodes: [TextNode('@Greg Price')]));

    testParseInline('silent user @-mention',
      // "@_**Greg Price**"
      '<p><span class="user-mention silent" data-user-id="2187">Greg Price</span></p>',
      const UserMentionNode(nodes: [TextNode('Greg Price')]));

    testParseInline('silent user @-mention, class order reversed',
      // "@_**Greg Price**" (hypothetical server variation)
      '<p><span class="silent user-mention" data-user-id="2187">Greg Price</span></p>',
      const UserMentionNode(nodes: [TextNode('Greg Price')]));

    testParseInline('plain group @-mention',
      // "@*test-empty*"
      '<p><span class="user-group-mention" data-user-group-id="186">@test-empty</span></p>',
      const UserMentionNode(nodes: [TextNode('@test-empty')]));

    testParseInline('silent group @-mention',
      // "@_*test-empty*"
      '<p><span class="user-group-mention silent" data-user-group-id="186">test-empty</span></p>',
      const UserMentionNode(nodes: [TextNode('test-empty')]));

    testParseInline('silent group @-mention, class order reversed',
      // "@_*test-empty*" (hypothetical server variation)
      '<p><span class="silent user-group-mention" data-user-group-id="186">test-empty</span></p>',
      const UserMentionNode(nodes: [TextNode('test-empty')]));

    // TODO test wildcard mentions
  });

  testParseExample(ContentExample.emojiUnicode);
  testParseExample(ContentExample.emojiUnicodeClassesFlipped);
  testParseExample(ContentExample.emojiUnicodeMultiCodepoint);
  testParseExample(ContentExample.emojiUnicodeLiteral);
  testParseExample(ContentExample.emojiCustom);
  testParseExample(ContentExample.emojiCustomInvalidUrl);
  testParseExample(ContentExample.emojiZulipExtra);

  testParseExample(ContentExample.mathInline);

  group('global times', () {
    testParseInline('smoke',
      // "<time:2024-01-30T17:33:00Z>"
      '<p><time datetime="2024-01-30T17:33:00Z">2024-01-30T17:33:00Z</time></p>',
      GlobalTimeNode(datetime: DateTime.parse('2024-01-30T17:33Z')),
    );

    testParseInline('handles missing attribute',
      // No markdown, this is unexpected response
      '<p><time>2024-01-30T17:33:00Z</time></p>',
      inlineUnimplemented('<time>2024-01-30T17:33:00Z</time>'),
    );

    testParseInline('handles DateTime.parse failure',
      // No markdown, this is unexpected response
      '<p><time datetime="2024">2024-01-30T17:33:00Z</time></p>',
      inlineUnimplemented('<time datetime="2024">2024-01-30T17:33:00Z</time>'),
    );

    testParseInline('handles unexpected timezone',
      // No markdown, this is unexpected response
      '<p><time datetime="2024-01-30T17:33:00">2024-01-30T17:33:00</time></p>',
      inlineUnimplemented('<time datetime="2024-01-30T17:33:00">2024-01-30T17:33:00</time>'),
    );
  });

  //
  // Block content.
  //

  testParse('parse <br> in block context',
    '<br><p>a</p><br>', const [ // TODO not sure how to reproduce this example
      LineBreakNode(),
      ParagraphNode(links: null, nodes: [TextNode('a')]),
      LineBreakNode(),
    ]);

  testParse('parse two plain-text paragraphs',
    // "hello\n\nworld"
    '<p>hello</p>\n<p>world</p>', const [
      ParagraphNode(links: null, nodes: [TextNode('hello')]),
      ParagraphNode(links: null, nodes: [TextNode('world')]),
    ]);

  group('parse headings', () {
    testParse('plain h6',
      // "###### six"
      '<h6>six</h6>', const [
        HeadingNode(level: HeadingLevel.h6, links: null, nodes: [TextNode('six')])]);

    testParse('containing inline markup',
      // "###### one [***`two`***](https://example/)"
      '<h6>one <a href="https://example/"><strong><em><code>two'
          '</code></em></strong></a></h6>', const [
        HeadingNode(level: HeadingLevel.h6, links: null, nodes: [
          TextNode('one '),
          LinkNode(url: 'https://example/',
            nodes: [StrongNode(nodes: [EmphasisNode(nodes: [
              InlineCodeNode(nodes: [TextNode('two')])])])]),
        ])]);

    testParse('amidst paragraphs',
      // "intro\n###### section\ntext"
      "<p>intro</p>\n<h6>section</h6>\n<p>text</p>", const [
        ParagraphNode(links: null, nodes: [TextNode('intro')]),
        HeadingNode(level: HeadingLevel.h6, links: null, nodes: [TextNode('section')]),
        ParagraphNode(links: null, nodes: [TextNode('text')]),
      ]);

    testParse('h1, h2, h3, h4, h5',
      // "# one\n## two\n### three\n#### four\n##### five"
      '<h1>one</h1>\n<h2>two</h2>\n<h3>three</h3>\n<h4>four</h4>\n<h5>five</h5>', const [
        HeadingNode(level: HeadingLevel.h1, links: null, nodes: [TextNode('one')]),
        HeadingNode(level: HeadingLevel.h2, links: null, nodes: [TextNode('two')]),
        HeadingNode(level: HeadingLevel.h3, links: null, nodes: [TextNode('three')]),
        HeadingNode(level: HeadingLevel.h4, links: null, nodes: [TextNode('four')]),
        HeadingNode(level: HeadingLevel.h5, links: null, nodes: [TextNode('five')]),
      ]);
  });

  group('parse lists', () {
    testParse('<ol>',
      // "1. first\n2. then"
      '<ol>\n<li>first</li>\n<li>then</li>\n</ol>', const [
        ListNode(ListStyle.ordered, [
          [ParagraphNode(wasImplicit: true, links: null, nodes: [TextNode('first')])],
          [ParagraphNode(wasImplicit: true, links: null, nodes: [TextNode('then')])],
        ]),
      ]);

    testParse('<ul>',
      // "* something\n* another"
      '<ul>\n<li>something</li>\n<li>another</li>\n</ul>', const [
        ListNode(ListStyle.unordered, [
          [ParagraphNode(wasImplicit: true, links: null, nodes: [TextNode('something')])],
          [ParagraphNode(wasImplicit: true, links: null, nodes: [TextNode('another')])],
        ]),
      ]);

    testParse('implicit paragraph with internal <br>',
      // "* a\n  b"
      '<ul>\n<li>a<br>\n  b</li>\n</ul>', const [
        ListNode(ListStyle.unordered, [
          [ParagraphNode(wasImplicit: true, links: null, nodes: [
            TextNode('a'),
            LineBreakInlineNode(),
            TextNode('\n  b'), // TODO: this renders misaligned
          ])],
        ])
      ]);

    testParse('explicit paragraphs',
      // "* a\n\n  b"
      '<ul>\n<li>\n<p>a</p>\n<p>b</p>\n</li>\n</ul>', const [
        ListNode(ListStyle.unordered, [
          [
            ParagraphNode(links: null, nodes: [TextNode('a')]),
            ParagraphNode(links: null, nodes: [TextNode('b')]),
          ],
        ]),
      ]);
  });

  group('track links inside block-inline containers', () {
    testParse('multiple links in paragraph',
      // "before[text](/there)mid[other](/else)after"
      '<p>before<a href="/there">text</a>mid'
          '<a href="/else">other</a>after</p>', const [
        ParagraphNode(links: null, nodes: [
          TextNode('before'),
          LinkNode(url: '/there', nodes: [TextNode('text')]),
          TextNode('mid'),
          LinkNode(url: '/else', nodes: [TextNode('other')]),
          TextNode('after'),
        ])]);

    testParse('link in heading',
      // "###### [t](/u)\nhi"
      '<h6><a href="/u">t</a></h6>\n<p>hi</p>', const [
        HeadingNode(links: null, level: HeadingLevel.h6, nodes: [
          LinkNode(url: '/u', nodes: [TextNode('t')]),
        ]),
        ParagraphNode(links: null, nodes: [TextNode('hi')]),
      ]);

    testParse('link in list item',
      // "* [t](/u)"
      '<ul>\n<li><a href="/u">t</a></li>\n</ul>', const [
        ListNode(ListStyle.unordered, [
          [ParagraphNode(links: null, wasImplicit: true, nodes: [
            LinkNode(url: '/u', nodes: [TextNode('t')]),
          ])],
        ])]);
  });

  testParseExample(ContentExample.quotation);

  testParseExample(ContentExample.codeBlockPlain);
  testParseExample(ContentExample.codeBlockHighlightedShort);
  testParseExample(ContentExample.codeBlockHighlightedMultiline);
  testParseExample(ContentExample.codeBlockWithHighlightedLines);
  testParseExample(ContentExample.codeBlockWithUnknownSpanType);

  testParseExample(ContentExample.mathBlock);
  testParseExample(ContentExample.mathBlockInQuote);

  testParseExample(ContentExample.imageSingle);
  testParseExample(ContentExample.imageInvalidUrl);
  testParseExample(ContentExample.imageCluster);
  testParseExample(ContentExample.imageClusterThenContent);
  testParseExample(ContentExample.imageMultipleClusters);
  testParseExample(ContentExample.imageInImplicitParagraph);
  testParseExample(ContentExample.imageClusterInImplicitParagraph);
  testParseExample(ContentExample.imageClusterInImplicitParagraphThenContent);

  testParse('parse nested lists, quotes, headings, code blocks',
    // "1. > ###### two\n   > * three\n\n      four"
    '<ol>\n<li>\n<blockquote>\n<h6>two</h6>\n<ul>\n<li>three</li>\n'
        '</ul>\n</blockquote>\n<div class="codehilite"><pre><span></span>'
        '<code>four\n</code></pre></div>\n\n</li>\n</ol>', const [
      ListNode(ListStyle.ordered, [[
        QuotationNode([
          HeadingNode(level: HeadingLevel.h6, links: null, nodes: [TextNode('two')]),
          ListNode(ListStyle.unordered, [[
            ParagraphNode(wasImplicit: true, links: null, nodes: [TextNode('three')]),
          ]]),
        ]),
        CodeBlockNode([
          CodeBlockSpanNode(text: 'four', type: CodeBlockSpanType.text),
        ]),
        ParagraphNode(wasImplicit: true, links: null, nodes: [TextNode('\n\n')]), // TODO avoid this; it renders wrong
      ]]),
    ]);

  test('all content examples are tested', () {
    // Check that every ContentExample defined above has a corresponding
    // actual test case that runs on it.  If you've added a new example
    // and this test breaks, remember to add a `testParseExample` call for it.

    // This implementation is a bit of a hack; it'd be cleaner to get the
    // actual Dart parse tree using package:analyzer.  Unfortunately that
    // approach takes several seconds just to load the parser library, enough
    // to add noticeably to the runtime of our whole test suite.
    final thisFilename = Trace.current().frames[0].uri.path;
    final source = File(thisFilename).readAsStringSync();
    final declaredExamples = RegExp(multiLine: true,
      r'^\s*static\s+(?:const|final)\s+(\w+)\s*=\s*ContentExample\s*(?:\.\s*inline\s*)?\(',
    ).allMatches(source).map((m) => m.group(1));
    final testedExamples = RegExp(multiLine: true,
      r'^\s*testParseExample\s*\(\s*ContentExample\s*\.\s*(\w+)\);',
    ).allMatches(source).map((m) => m.group(1));
    check(testedExamples).unorderedEquals(declaredExamples);
  });
}
