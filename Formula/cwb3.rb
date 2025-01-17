class Cwb3 < Formula
  desc "Tools for managing and querying large text corpora with linguistic annotations"
  homepage "https://cwb.sourceforge.io/"
  url "https://downloads.sourceforge.net/project/cwb/cwb/cwb-3.5-RC/cwb-3.4.33-src.tar.gz"
  sha256 "856b72785522d42f13f4a0528d2b80c2bf422c10411234a8e4b61df111af77dd"
  license "GPL-2.0-or-later"
  head "svn://svn.code.sf.net/p/cwb/code/cwb/trunk"

  bottle do
    sha256 cellar: :any,                 arm64_monterey: "58a4e7511ce2b101990a19f53e9c23056ad6bbd1548ea58b35b0d44c18a263a5"
    sha256 cellar: :any,                 arm64_big_sur:  "6bf55b83b4a38bb31b6725401ee566b483e2d4f9f9e599d7f93fa002b98193a4"
    sha256 cellar: :any,                 monterey:       "bcbb0414f2a9a9a4289aee4ab440c8d583de77b69453706943f05d60ac4ba152"
    sha256 cellar: :any,                 big_sur:        "52d7e82f3d7729b12f4eddd19805bdb9444a6613105ef861610b19240b5cd068"
    sha256 cellar: :any,                 catalina:       "27f369e784f165896c5004724b1ca9a5bc1be64b3d76fb9a0b007e25eb6557a7"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "805ab2c59d1fa16ec0de990e9b6283c04ebb4d5e8a2ba54648eb719fc0d39204"
  end

  depends_on "pkg-config" => :build
  depends_on "gettext"
  depends_on "glib"
  depends_on "pcre"
  depends_on "readline"

  uses_from_macos "bison" => :build
  uses_from_macos "flex" => :build
  uses_from_macos "ncurses"

  resource("tutorial_data") do
    url "https://cwb.sourceforge.io/files/encoding_tutorial_data.zip"
    sha256 "bbd37514fdbdfd25133808afec6a11037fb28253e63446a9e548fb437cbdc6f0"
  end

  def install
    args = %W[
      PLATFORM=homebrew-formula
      SITE=homebrew-formula
      FULL_MESSAGES=1
      PREFIX=#{prefix}
      HOMEBREW_ROOT=#{HOMEBREW_PREFIX}
    ]

    system "make", "all", *args
    ENV.deparallelize
    system "make", "install", *args
  end

  def default_registry
    HOMEBREW_PREFIX/"share/cwb/registry"
  end

  def post_install
    # make sure default registry exists
    default_registry.mkpath
  end

  def caveats
    <<~STOP
      CWB default registry directory: #{default_registry}
    STOP
  end

  test do
    resource("tutorial_data").stage do
      Pathname("registry").mkdir
      Pathname("data").mkdir

      system(bin/"cwb-encode", "-c", "ascii",
        "-d", "data", "-R", "registry/ex", "-f", "example.vrt",
        "-P", "pos", "-P", "lemma", "-S", "s:0")
      assert_predicate(Pathname("registry")/"ex", :exist?,
        "registry file has been created")
      assert_predicate(Pathname("data")/"lemma.lexicon", :exist?,
        "lexicon file for p-attribute lemma has been created")

      system(bin/"cwb-makeall", "-r", "registry", "EX")
      assert_predicate(Pathname("data")/"lemma.corpus.rev", :exist?,
        "reverse index file for p-attribute lemma has been created")

      assert_equal("Tokens:\t5\nTypes:\t5\n",
        shell_output("#{bin}/cwb-lexdecode -r registry -S EX"),
        "correct token & type count for p-attribute")
      assert_equal("0\t4\n",
        shell_output("#{bin}/cwb-s-decode -r registry EX -S s"),
        "correct span for s-attribute")

      assert_equal("3\n",
        shell_output("#{bin}/cqpcl -r registry -D EX 'A=[pos = \"\\w{2}\"]; size A;'"),
        "CQP query works correctly")

      Pathname("test.c").write <<~STOP
        #include <stdlib.h>
        #include <cwb/cl.h>

        int main(int argc, char *argv[]) {
          int *id, n_id, n_token;
          Corpus *C = cl_new_corpus("registry", "ex");
          Attribute *word = cl_new_attribute(C, "word", ATT_POS);
          id = cl_regex2id(word, "\\\\p{Ll}+", 0, &n_id);
          if (n_id > 0)
            n_token = cl_idlist2freq(word, id, n_id);
          else
            n_token = 0;
          printf("%d\\n", n_token);
          return 0;
        }
      STOP
      cppflags = Utils.safe_popen_read("#{bin}/cwb-config", "-I").strip.split
      ldflags = Utils.safe_popen_read("#{bin}/cwb-config", "-L").strip.split
      system ENV.cc, "-o", "test", *cppflags, "test.c", *ldflags
      assert_equal("3\n", shell_output("./test"),
        "compiled test program works")
    end
  end
end
