import type { Metadata } from "next";
import { ReactQueryProvider } from "@/di/react-query-provider";
import { AuthProvider } from "@/context/auth-context";
import { ThemeProvider } from "@/context/theme-context";
import { ToastProvider } from "@/components/ui/toast";
import { themeInitScript } from "@/lib/theme";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "MoMoPlus Admin",
    template: "%s | MoMoPlus Admin",
  },
  description: "Internal admin dashboard for MoMoPlus operations and support teams.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="antialiased">
        <script dangerouslySetInnerHTML={{ __html: themeInitScript }} />
        <ToastProvider>
          <ThemeProvider>
            <AuthProvider>
              <ReactQueryProvider>{children}</ReactQueryProvider>
            </AuthProvider>
          </ThemeProvider>
        </ToastProvider>
      </body>
    </html>
  );
}
