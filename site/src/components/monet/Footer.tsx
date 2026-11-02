"use client";

// ============================================================================
// CUSTOMIZATION
// ============================================================================

const COLORS = {
  light: {
    bg: "#F5F5F5",
    text: "#1F1F1F",
    textSecondary: "#6B7280",
    border: "#E5E5E5",
  },
  dark: {
    bg: "#0d0b08",
    text: "#FFFFFF",
    textSecondary: "#9CA3AF",
    border: "#333333",
  },
} as const;

const FOOTER_LINKS = {
  roastfetch: [
    { label: "Install", href: "#install" },
    { label: "Source", href: "https://github.com/ethembeldagli/roastfetch", external: true },
    { label: "Add a roast", href: "https://github.com/ethembeldagli/roastfetch#add-a-roast-for-your-distro", external: true },
  ],
  "Also by me": [
    { label: "Terminal Wrapped", href: "https://github.com/ethembeldagli/termwrapped", external: true },
    { label: "Millennium for Bazzite", href: "https://github.com/ethembeldagli/millennium-bazzite", external: true },
  ],
  "Fine print": [
    { label: "MIT licence", href: "https://github.com/ethembeldagli/roastfetch/blob/main/LICENSE", external: true },
    { label: "Runs offline", href: "#install" },
  ],
} as const;

// ============================================================================

import { motion } from "motion/react";

interface CursorComFooter9Props {
  mode?: "light" | "dark";
}

export default function CursorComFooter9({
  mode = "dark",
}: CursorComFooter9Props) {
  const colors = COLORS[mode];

  return (
    <footer
      className="w-full px-6 py-12 lg:px-12 lg:py-16"
      style={{ backgroundColor: colors.bg }}
    >
      <div className="mx-auto max-w-7xl">
        {/* Links Grid */}
        <nav className="mb-12 grid grid-cols-2 gap-8 md:grid-cols-5">
          {Object.entries(FOOTER_LINKS).map(([category, links]) => (
            <div key={category}>
              <h3
                className="mb-4 text-sm font-medium"
                style={{ color: colors.textSecondary }}
              >
                {category}
              </h3>
              <ul className="space-y-2">
                {links.map((link) => (
                  <li key={link.label}>
                    <a
                      href={link.href}
                      target={link.external ? "_blank" : undefined}
                      rel={link.external ? "noopener noreferrer" : undefined}
                      className="inline-flex items-center gap-1 text-sm transition-colors hover:opacity-80"
                      style={{ color: colors.text }}
                    >
                      {link.label}
                      {link.external && (
                        <span className="text-xs opacity-0 transition-opacity group-hover:opacity-100">
                          ↗
                        </span>
                      )}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </nav>

        {/* Bottom Bar */}
        <div className="flex flex-col items-start justify-between gap-4 md:flex-row md:items-center">
          {/* Copyright */}
          <div
            className="flex items-center gap-4 text-sm"
            style={{ color: colors.textSecondary }}
          >
            <span>&copy; 2026 Ethem Beldagli · roastfetch</span>
          </div>

          
        </div>
      </div>
    </footer>
  );
}
