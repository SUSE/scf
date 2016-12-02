set -e

PATCH_DIR=$(ls -d /var/vcap/packages-src/*/src/github.com/cloudfoundry/cf-acceptance-tests)
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

read -r -d '' setup_patch_routing_transparency <<'PATCH' || true
commit e39c2846d092f5d4b79953e5271fce8bf2435300
Author: Zach Robinson <zrobinson@pivotal.io>
Date:   Wed Nov 30 11:05:06 2016 -0800

    update routing transparency tests to use golang app
    
    - extract transparency tests into a separate file
    - switch to golang from java because tomcat not prevents illegal uri
    characters from reaching the app
    
    Signed-off-by: Michael Xu <mxu@pivotal.io>

diff --git apps/encoding.go apps/encoding.go
index 19da6f1..9d3c32f 100644
--- apps/encoding.go
+++ apps/encoding.go
@@ -44,26 +44,4 @@ var _ = AppsDescribe("Encoding", func() {
 		}, Config.DefaultTimeoutDuration()).Should(ContainSubstring("It's Ω!"))
 		Expect(curlResponse).To(ContainSubstring("File encoding is UTF-8"))
 	})
-
-	Describe("Routing", func() {
-		It("Supports URLs with percent-encoded characters", func() {
-			var curlResponse string
-			Eventually(func() string {
-				curlResponse = helpers.CurlApp(Config, appName, "/requesturi/%21%7E%5E%24%20%27%28%29?foo=bar+baz%20bing")
-				return curlResponse
-			}, Config.DefaultTimeoutDuration()).Should(ContainSubstring("You requested some information about rio rancho properties"))
-			Expect(curlResponse).To(ContainSubstring("/requesturi/%21%7E%5E%24%20%27%28%29"))
-			Expect(curlResponse).To(ContainSubstring("Query String is [foo=bar+baz%20bing]"))
-		})
-
-		It("transparently proxies both reserved characters and unsafe characters", func() {
-			var curlResponse string
-			Eventually(func() string {
-				curlResponse = helpers.CurlApp(Config, appName, "/requesturi/!~^'()$\"?!'()$#!'")
-				return curlResponse
-			}, Config.DefaultTimeoutDuration()).Should(ContainSubstring("You requested some information about rio rancho properties"))
-			Expect(curlResponse).To(ContainSubstring("/requesturi/!~^'()$\""))
-			Expect(curlResponse).To(ContainSubstring("Query String is [!'()$]"))
-		})
-	})
 })
diff --git apps/routing_transparency.go apps/routing_transparency.go
new file mode 100644
index 0000000..7591064
--- /dev/null
+++ apps/routing_transparency.go
@@ -0,0 +1,56 @@
+package apps
+
+import (
+	. "github.com/cloudfoundry/cf-acceptance-tests/cats_suite_helpers"
+	. "github.com/onsi/ginkgo"
+	. "github.com/onsi/gomega"
+	. "github.com/onsi/gomega/gexec"
+
+	"github.com/cloudfoundry-incubator/cf-test-helpers/cf"
+	"github.com/cloudfoundry-incubator/cf-test-helpers/helpers"
+	"github.com/cloudfoundry/cf-acceptance-tests/helpers/app_helpers"
+	"github.com/cloudfoundry/cf-acceptance-tests/helpers/assets"
+	"github.com/cloudfoundry/cf-acceptance-tests/helpers/random_name"
+)
+
+var _ = AppsDescribe("Routing Transparency", func() {
+	var appName string
+
+	BeforeEach(func() {
+		appName = random_name.CATSRandomName("APP")
+		Expect(cf.Cf("push",
+			appName,
+			"--no-start",
+			"-b", Config.GetGoBuildpackName(),
+			"-p", assets.NewAssets().Golang,
+			"-m", DEFAULT_MEMORY_LIMIT,
+			"-d", Config.GetAppsDomain()).Wait(Config.CfPushTimeoutDuration())).To(Exit(0))
+		app_helpers.SetBackend(appName)
+		Expect(cf.Cf("start", appName).Wait(Config.CfPushTimeoutDuration())).To(Exit(0))
+	})
+
+	AfterEach(func() {
+		app_helpers.AppReport(appName, Config.DefaultTimeoutDuration())
+		Expect(cf.Cf("delete", appName, "-f", "-r").Wait(Config.DefaultTimeoutDuration())).To(Exit(0))
+	})
+
+	It("Supports URLs with percent-encoded characters", func() {
+		var curlResponse string
+		Eventually(func() string {
+			curlResponse = helpers.CurlApp(Config, appName, "/requesturi/%21%7E%5E%24%20%27%28%29?foo=bar+baz%20bing")
+			return curlResponse
+		}, Config.DefaultTimeoutDuration()).Should(ContainSubstring("Request"))
+		Expect(curlResponse).To(ContainSubstring("/requesturi/%21%7E%5E%24%20%27%28%29"))
+		Expect(curlResponse).To(ContainSubstring("Query String is [foo=bar+baz%20bing]"))
+	})
+
+	It("transparently proxies both reserved characters and unsafe characters", func() {
+		var curlResponse string
+		Eventually(func() string {
+			curlResponse = helpers.CurlApp(Config, appName, "/requesturi/!~^'()$\"?!'()$#!'")
+			return curlResponse
+		}, Config.DefaultTimeoutDuration()).Should(ContainSubstring("Request"))
+		Expect(curlResponse).To(ContainSubstring("/requesturi/!~^'()$\""))
+		Expect(curlResponse).To(ContainSubstring("Query String is [!'()$]"))
+	})
+})
diff --git assets/golang/site.go assets/golang/site.go
index f35bb12..0a4d0f5 100644
--- assets/golang/site.go
+++ assets/golang/site.go
@@ -8,6 +8,7 @@ import (
 
 func main() {
 	http.HandleFunc("/", hello)
+	http.HandleFunc("/requesturi/", echo)
 	fmt.Println("listening...")
 	err := http.ListenAndServe(":"+os.Getenv("PORT"), nil)
 	if err != nil {
@@ -18,3 +19,7 @@ func main() {
 func hello(res http.ResponseWriter, req *http.Request) {
 	fmt.Fprintln(res, "go, world")
 }
+
+func echo(res http.ResponseWriter, req *http.Request) {
+	fmt.Fprintln(res, fmt.Sprintf("Request URI is [%s]\\nQuery String is [%s]", req.RequestURI, req.URL.RawQuery))
+}
PATCH

cd "$PATCH_DIR"

echo -e "${setup_patch_routing_transparency}" | patch --force -p0

touch "${SENTINEL}"

exit 0
