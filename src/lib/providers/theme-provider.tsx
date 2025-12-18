"use client"

import * as React from "react"
import { ThemeProvider as NextThemsProvider } from "next-themes"

export function ThemeProvider({
  children,
  ...props
}: React.ComponentProps<typeof NextThemsProvider>) {
  return (
    <NextThemsProvider
      attribute="class"
      defaultTheme="system"
      enableSystem
      disableTransitionOnChange
      {...props}
    >
      {children}
    </NextThemsProvider>
  )
}
