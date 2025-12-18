#!/usr/bin/env bash
# This script is compatible with both Bash and Zsh

find . -mindepth 1 -delete
TEMP_DIR="./topcoderfullstack"
# --yes: Skip all prompts and use defaults for unprovided options
# No --react-compiler flag means React Compiler will be disabled (default: No)
bun create next-app@latest "$TEMP_DIR" --use-bun --typescript --eslint --tailwind --src-dir --app --turbopack --import-alias "@/*" --yes

# Move all files from temp directory to current directory
# Shell-agnostic dotglob handling
if [ -n "$BASH_VERSION" ]; then
    # Bash
    shopt -s dotglob
    mv "$TEMP_DIR"/* . 2>/dev/null || true
    shopt -u dotglob
elif [ -n "$ZSH_VERSION" ]; then
    # Zsh
    setopt dotglob
    mv "$TEMP_DIR"/* . 2>/dev/null || true
    unsetopt dotglob
else
    # Fallback for other shells - use explicit pattern
    mv "$TEMP_DIR"/* "$TEMP_DIR"/.[!.]* "$TEMP_DIR"/..?* . 2>/dev/null || true
fi

rm -rf "$TEMP_DIR"
bun add next-themes
rm -rf .git
git init

sed -i '' 's/"dev": "next dev --turbopack",/"dev": "next dev",\n    "dev:turbo": "next dev --turbopack",/' package.json
sed -i '' 's/"build": "next build --turbopack",/"build": "next build",\n    "build:turbo": "next build --turbopack",/' package.json

find public -mindepth 1 -delete
mkdir -p temp_backup
cp src/app/layout.tsx temp_backup/layout.tsx
find src -mindepth 1 -delete
mkdir -p src/app
cp temp_backup/layout.tsx src/app/layout.tsx
rm -rf temp_backup
echo '@import "tailwindcss";' > src/app/globals.css

bunx --bun shadcn@latest init --base-color neutral
bunx --bun shadcn@latest add --all --yes

mkdir src/lib/providers
cat > src/lib/providers/theme-provider.tsx << 'EOF'
"use client"

import * as React from "react"
import { ThemeProvider as NextThemesProvider } from "next-themes"

export function ThemeProvider({
  children,
  ...props
}: React.ComponentProps<typeof NextThemesProvider>) {
  return <NextThemesProvider {...props}>{children}</NextThemesProvider>
}
EOF

sed -i '' '3a\
import { ThemeProvider } from "@/lib/providers/theme-provider";
' src/app/layout.tsx

sed -i '' 's/<html lang="en">/<html lang="en" suppressHydrationWarning>/' src/app/layout.tsx

sed -i '' '/<body/,/>/{s/className={\(.*\)}/className={\1}\n        suppressHydrationWarning/;}' src/app/layout.tsx

sed -i '' '/<body/,/>/{s|>$|>\n        <ThemeProvider\n          attribute="class"\n          defaultTheme="system"\n          enableSystem\n          disableTransitionOnChange\n        >|;}' src/app/layout.tsx

sed -i '' 's|{children}|{children}\n        </ThemeProvider>|' src/app/layout.tsx

cat > src/app/page.tsx << 'EOF'
import Link from "next/link"

export default function HomePage() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <Link
        href="https://topcoderfullstack.com"
        target="_blank"
        rel="noopener noreferrer"
        className="text-4xl font-bold tracking-tight transition-colors hover:text-primary sm:text-6xl lg:text-7xl"
      >
        TOPCODER FULLSTACK
      </Link>
    </div>
  )
}
EOF

touch .env.local

bun add hono
bun add zod @hono/zod-validator
bun add @neondatabase/serverless
bun add @supabase/supabase-js @supabase/ssr
bun add drizzle-orm postgres dotenv
bun add -D drizzle-kit

set -e

echo "🚀 Setting up Quality Assurance Tools for Topcoder Fullstack Project"
echo "============================================================"


# Install quality assurance dev dependencies
echo ""
echo "📦 Installing quality assurance tools..."
bun add -d husky lint-staged eslint prettier typescript @typescript-eslint/parser @typescript-eslint/eslint-plugin @commitlint/cli @commitlint/config-conventional eslint-config-prettier eslint-plugin-prettier eslint-plugin-react eslint-plugin-react-hooks prettier-plugin-tailwindcss

# Modify ESLint config to ignore shadcn/ui components
echo ""
echo "📝 Modifying ESLint configuration..."
# The eslint.config.mjs is already created by Next.js
# We need to add shadcn/ui components directory to globalIgnores
node << 'NODESCRIPT'
const fs = require('fs');
const eslintConfigPath = 'eslint.config.mjs';

// Read the existing config
let configContent = fs.readFileSync(eslintConfigPath, 'utf8');

// Find the globalIgnores array and add shadcn/ui components path
// Pattern to match: "next-env.d.ts",
// We'll add the new ignore right after it
const pattern = /"next-env\.d\.ts",/;
const replacement = `"next-env.d.ts",
    // Ignore shadcn/ui components (third-party generated code)
    "src/components/ui/**",`;

// Replace the config to include the new ignore path
configContent = configContent.replace(pattern, replacement);

// Write the modified config back
fs.writeFileSync(eslintConfigPath, configContent, 'utf8');
console.log('✅ ESLint config modified successfully - shadcn/ui components will be ignored');
NODESCRIPT

# Add ESLint cache to .gitignore
echo "" >> .gitignore
echo "# eslint cache" >> .gitignore
echo ".eslintcache" >> .gitignore
echo "✅ Added .eslintcache to .gitignore"

# Create Prettier config
echo ""
echo "📝 Creating Prettier configuration..."
cat > .prettierrc << 'EOF'
{
  "printWidth": 80,
  "tabWidth": 2,
  "useTabs": false,
  "semi": false,
  "singleQuote": false,
  "quoteProps": "as-needed",
  "jsxSingleQuote": false,
  "trailingComma": "es5",
  "bracketSpacing": true,
  "bracketSameLine": false,
  "arrowParens": "always",
  "endOfLine": "lf",
  "htmlWhitespaceSensitivity": "css",
  "embeddedLanguageFormatting": "auto",
  "vueIndentScriptAndStyle": false,
  "singleAttributePerLine": false,
  "proseWrap": "preserve",
  "plugins": ["prettier-plugin-tailwindcss"]
}

EOF

cat > .prettierignore << 'EOF'
node_modules
.next
out
build
dist
coverage
.git
*.log
bun.lockb
package-lock.json
yarn.lock
pnpm-lock.yaml
.gitignore
.prettierignore
EOF

# Create commitlint config
echo ""
echo "📝 Creating commitlint configuration..."
cat > commitlint.config.js << 'EOF'
module.exports = {
  // 继承的规则配置 | Extended rule configuration
  extends: ["@commitlint/config-conventional"],
  // @commitlint/config-conventional 提供了 Angular 风格的提交规范 | Provides Angular-style commit conventions

  // 自定义规则 | Custom rules
  rules: {
    // 提交类型规则 | Commit type rules
    "type-enum": [
      2, // 级别：0-禁用，1-警告，2-错误 | Level: 0-disable, 1-warning, 2-error
      "always", // 应用时机：always-始终检查，never-从不检查 | When: always-always check, never-never check
      [
        // 允许的提交类型列表 | Allowed commit types
        "feat", // 新功能 | New feature
        "fix", // 修复 bug | Bug fix
        "docs", // 仅文档更改 | Documentation only changes
        "style", // 不影响代码含义的更改（空白、格式化、缺少分号等）| Changes that don't affect code meaning
        "refactor", // 既不修复错误也不添加功能的代码更改 | Code change that neither fixes a bug nor adds a feature
        "perf", // 提高性能的代码更改 | Code change that improves performance
        "test", // 添加缺失的测试或更正现有测试 | Adding missing tests or correcting existing tests
        "build", // 影响构建系统或外部依赖的更改 | Changes to build system or external dependencies
        "ci", // 对 CI 配置文件和脚本的更改 | Changes to CI configuration files and scripts
        "chore", // 其他不修改 src 或测试文件的更改 | Other changes that don't modify src or test files
        "revert", // 撤销之前的提交 | Reverts a previous commit

        // 可选的自定义类型（根据需要取消注释）| Optional custom types (uncomment as needed)
        'wip',      // 进行中的工作 | Work in progress
        'ui',       // UI/UX 改进 | UI/UX improvements
        'release',  // 发布相关更改 | Release related changes
        'deploy',   // 部署相关更改 | Deployment related changes
        'hotfix',   // 紧急修复 | Emergency fix
        'merge',    // 合并分支 | Merge branches
        'init',     // 初始提交 | Initial commit
        'security', // 安全相关更改 | Security related changes
        'upgrade',  // 升级依赖 | Upgrade dependencies
        'downgrade',// 降级依赖 | Downgrade dependencies
        'i18n',     // 国际化相关 | Internationalization related
        'typo',     // 修正拼写错误 | Fix typos
        'dep',      // 添加或删除依赖 | Add or remove dependencies
      ],
    ],

    // 提交类型大小写规则 | Type case rules
    "type-case": [
      2,
      "always",
      "lower-case", // 必须小写 | Must be lowercase
      // 其他选项：upper-case, camel-case, kebab-case, pascal-case, snake-case, start-case
    ],

    // 提交范围（scope）规则 | Scope rules
    "scope-case": [
      2,
      "always",
      "lower-case", // scope 必须小写 | Scope must be lowercase
    ],

    // scope 允许为空 | Scope can be empty
    "scope-empty": [
      0, // 禁用此规则，允许空 scope | Disable this rule, allow empty scope
      "never",
    ],

    // 自定义 scope 枚举（根据项目模块定制）| Custom scope enum (customize based on project modules)
    // 'scope-enum': [
    //   2,
    //   'always',
    //   [
    //     'components',  // 组件相关 | Component related
    //     'utils',       // 工具函数 | Utility functions
    //     'styles',      // 样式相关 | Style related
    //     'config',      // 配置相关 | Configuration related
    //     'api',         // API 相关 | API related
    //     'store',       // 状态管理 | State management
    //     'routes',      // 路由相关 | Routing related
    //     'tests',       // 测试相关 | Test related
    //     'deps',        // 依赖相关 | Dependency related
    //     'auth',        // 认证相关 | Authentication related
    //     'db',          // 数据库相关 | Database related
    //   ],
    // ],

    // 主题（subject）规则 | Subject rules
    "subject-case": [
      2,
      "always",
      "lower-case", // 主题必须小写开头 | Subject must start with lowercase
      // 注：通常建议首字母小写，但不强制整个主题都小写 | Note: Usually first letter lowercase is recommended
    ],

    // 主题不能为空 | Subject cannot be empty
    "subject-empty": [
      2,
      "never", // 不允许空主题 | Don't allow empty subject
    ],

    // 主题末尾不要句号 | No period at end of subject
    "subject-full-stop": [
      2,
      "never",
      ".", // 不允许以句号结尾 | Don't allow period at end
    ],

    // 主题最大长度 | Subject max length
    "subject-max-length": [
      2,
      "always",
      100, // 主题最多 100 个字符 | Subject max 100 characters
    ],

    // 主题最小长度 | Subject min length
    "subject-min-length": [
      2,
      "always",
      3, // 主题至少 3 个字符 | Subject min 3 characters
    ],

    // 头部最大长度（type(scope): subject）| Header max length
    "header-max-length": [
      2,
      "always",
      100, // 整个头部最多 100 个字符 | Entire header max 100 characters
    ],

    // 正文（body）规则 | Body rules
    "body-leading-blank": [
      1, // 警告级别 | Warning level
      "always", // 正文前必须有空行 | Must have blank line before body
    ],

    // 正文每行最大长度 | Body line max length
    "body-max-line-length": [
      2,
      "always",
      100, // 正文每行最多 100 个字符 | Body lines max 100 characters
    ],

    // 正文最小长度 | Body min length
    // 'body-min-length': [
    //   2,
    //   'always',
    //   10, // 如果有正文，至少 10 个字符 | If body exists, min 10 characters
    // ],

    // 页脚（footer）规则 | Footer rules
    "footer-leading-blank": [
      1,
      "always", // 页脚前必须有空行 | Must have blank line before footer
    ],

    // 页脚每行最大长度 | Footer line max length
    "footer-max-line-length": [
      2,
      "always",
      100, // 页脚每行最多 100 个字符 | Footer lines max 100 characters
    ],

    // 签名规则（Signed-off-by）| Signature rules
    // 'signed-off-by': [
    //   2,
    //   'always',
    //   'Signed-off-by:', // 要求签名 | Require signature
    // ],

    // 自定义规则（根据团队需求添加）| Custom rules (add based on team needs)
    // 'references-empty': [
    //   2,
    //   'never', // 必须包含 issue 引用 | Must include issue reference
    // ],
  },

  // 提示配置 | Prompt configuration
  prompt: {
    settings: {},
    messages: {
      skip: ":skip", // 跳过 | Skip
      max: "最多 %d 个字符 | Upper %d chars",
      min: "至少 %d 个字符 | %d chars minimum",
      emptyWarning: "不能为空 | Can not be empty",
      upperLimitWarning: "超过限制 | Over limit",
      lowerLimitWarning: "低于限制 | Below limit",
    },
    questions: {
      type: {
        description: "请选择提交类型 | Select the type of change",
        enum: {
          feat: {
            description: "新功能 | A new feature",
            title: "Features",
            emoji: "✨",
          },
          fix: {
            description: "修复 Bug | A bug fix",
            title: "Bug Fixes",
            emoji: "🐛",
          },
          docs: {
            description: "仅文档更改 | Documentation only changes",
            title: "Documentation",
            emoji: "📚",
          },
          style: {
            description:
              "不影响代码含义的更改 | Markup, white-space, formatting, missing semi-colons...",
            title: "Styles",
            emoji: "💎",
          },
          refactor: {
            description:
              "代码重构，既不修复错误也不添加功能 | A code change that neither fixes a bug nor adds a feature",
            title: "Code Refactoring",
            emoji: "📦",
          },
          perf: {
            description:
              "提高性能的代码更改 | A code change that improves performance",
            title: "Performance Improvements",
            emoji: "🚀",
          },
          test: {
            description:
              "添加缺失的测试或更正现有测试 | Adding missing tests or correcting existing tests",
            title: "Tests",
            emoji: "🚨",
          },
          build: {
            description:
              "影响构建系统或外部依赖的更改 | Changes that affect the build system or external dependencies",
            title: "Builds",
            emoji: "🛠",
          },
          ci: {
            description:
              "对 CI 配置文件和脚本的更改 | Changes to our CI configuration files and scripts",
            title: "Continuous Integrations",
            emoji: "⚙️",
          },
          chore: {
            description:
              "其他不修改源代码或测试文件的更改 | Other changes that don't modify src or test files",
            title: "Chores",
            emoji: "♻️",
          },
          revert: {
            description: "撤销之前的提交 | Reverts a previous commit",
            title: "Reverts",
            emoji: "🗑",
          },
        },
      },
      scope: {
        description:
          "此更改的范围是什么（例如组件或文件名）| What is the scope of this change (e.g. component or file name)",
      },
      subject: {
        description:
          "写一个简短的、命令式的时态描述 | Write a short, imperative tense description of the change",
      },
      body: {
        description:
          "提供更详细的更改描述（可选）| Provide a longer description of the change (optional)",
      },
      breaking: {
        description:
          "列出任何破坏性变更（可选）| List any BREAKING CHANGES (optional)",
      },
      issues: {
        description:
          "列出此更改关闭的任何 ISSUES（可选）| List any ISSUES CLOSED by this change (optional)",
      },
    },
  },

  // 忽略某些提交的规则检查 | Ignore rules for certain commits
  ignores: [
    // 忽略自动生成的提交 | Ignore auto-generated commits
    (commit) => commit.includes("auto-generated"),
    // 忽略版本标签 | Ignore version tags
    (commit) => commit.includes("[skip ci]"),
    // 忽略 Merge 提交 | Ignore merge commits
    (commit) => commit.match(/^Merge/),
  ],

  // 默认忽略规则 | Default ignore rules
  defaultIgnores: true, // 是否使用默认忽略规则 | Whether to use default ignore rules

  // 帮助链接 | Help URL
  helpUrl:
    "https://github.com/conventional-changelog/commitlint/#what-is-commitlint",
}

/*
提交信息格式 | Commit Message Format:
<type>(<scope>): <subject>
<BLANK LINE>
<body>
<BLANK LINE>
<footer>

示例 | Examples:
1. feat(auth): add login functionality
2. fix(ui): resolve button alignment issue
3. docs: update README with new API endpoints
4. style(components): format code with prettier
5. refactor(utils): simplify date formatting logic
6. perf(api): optimize database queries
7. test(auth): add unit tests for login service
8. build(deps): upgrade React to v18
9. ci: add GitHub Actions workflow
10. chore: update .gitignore

带正文和页脚的示例 | Example with body and footer:
fix(auth): prevent race condition in token refresh

The token refresh logic had a race condition when multiple
requests triggered refresh simultaneously. Added mutex lock
to ensure only one refresh happens at a time.

Fixes #123
BREAKING CHANGE: Token refresh API now returns different format
*/
EOF

# Create lint-staged config
echo ""
echo "📝 Creating lint-staged configuration..."
cat > .lintstagedrc.js << 'EOF'
module.exports = {
  // TypeScript 和 JavaScript 文件处理规则 | TypeScript and JavaScript file rules
  "*.{ts,tsx,js,jsx}": [
    // 1. ESLint 检查并自动修复 | ESLint check and auto-fix
    // 使用 --cache 加速，--no-warn-ignored 避免警告忽略文件
    // Use --cache for speed, --no-warn-ignored to avoid warnings on ignored files
    "eslint --fix --cache --no-warn-ignored",
    // --fix: 自动修复可修复的问题 | Auto-fix fixable issues
    // --cache: 只检查更改的文件，大幅提升性能 | Only check changed files, greatly improves performance

    // 2. Prettier 格式化 | Prettier formatting
    "prettier --write",
    // --write: 直接修改文件 | Modify files directly

    // 其他可选命令（根据需要取消注释）| Other optional commands (uncomment as needed)
    // 'eslint --fix --max-warnings 0',      // 将警告视为错误 | Treat warnings as errors
    // 'tsc --noEmit',                        // TypeScript 类型检查（可能较慢）| TypeScript type check (may be slow)
    // 'jest --bail --findRelatedTests',      // 运行相关测试 | Run related tests
  ],

  // JSON 文件处理规则 | JSON file rules
  "*.{json,jsonc}": [
    // Prettier 格式化 JSON | Format JSON with Prettier
    "prettier --write",
    // JSON 文件不需要 ESLint 检查 | JSON files don't need ESLint
  ],

  // Markdown 文件处理规则 | Markdown file rules
  "*.{md,mdx}": [
    // Prettier 格式化 Markdown | Format Markdown with Prettier
    "prettier --write",
    // 可选：Markdown lint 工具（如需要请取消注释）| Optional: Markdown lint tool (uncomment if needed)
    // 'markdownlint --fix',
  ],

  // CSS/SCSS/Less 文件处理规则 | CSS/SCSS/Less file rules
  "*.{css,scss,less}": [
    // Prettier 格式化样式文件 | Format style files with Prettier
    "prettier --write",
    // 可选：StyleLint（如需要请取消注释）| Optional: StyleLint (uncomment if needed)
    // 'stylelint --fix',
  ],

  // HTML 文件处理规则 | HTML file rules
  "*.{html,htm}": [
    // Prettier 格式化 HTML | Format HTML with Prettier
    "prettier --write",
    // 可选：HTMLHint（如需要请取消注释）| Optional: HTMLHint (uncomment if needed)
    // 'htmlhint',
  ],

  // YAML 文件处理规则 | YAML file rules
  "*.{yml,yaml}": [
    // Prettier 格式化 YAML | Format YAML with Prettier
    "prettier --write",
  ],

  // 图片文件优化（如需要请取消注释）| Image file optimization (uncomment if needed)
  // '*.{png,jpg,jpeg,gif,svg}': [
  //   // 使用 imagemin 优化图片 | Optimize images with imagemin
  //   'imagemin-lint-staged',
  // ],

  // 其他配置文件格式化 | Other config files formatting
  "*.{toml,ini,cfg}": [
    // Prettier 格式化配置文件 | Format config files with Prettier
    "prettier --write",
  ],

  // 包管理器文件 | Package manager files
  "package.json": [
    // Prettier 格式化 | Format with Prettier
    "prettier --write",
    // 可选：排序 package.json（如需要请取消注释）| Optional: Sort package.json (uncomment if needed)
    // 'sort-package-json',
  ],

  // 忽略文件配置 | Ignore file configuration
  // 注意：.gitignore 等文件没有 Prettier 解析器，不应该用 prettier 处理
  // Note: .gitignore and similar files don't have a Prettier parser, should not be processed by prettier
  // ".{gitignore,prettierignore,eslintignore}": [
  //   "prettier --write",
  // ],

  // Shell 脚本（如需要请取消注释）| Shell scripts (uncomment if needed)
  // '*.{sh,bash}': [
  //   // Shell 脚本检查 | Shell script check
  //   'shellcheck',
  //   // Shell 脚本格式化 | Shell script formatting
  //   'shfmt -w',
  // ],

  // Python 文件（如需要请取消注释）| Python files (uncomment if needed)
  // '*.py': [
  //   // Python 格式化和检查 | Python formatting and linting
  //   'black',
  //   'pylint',
  // ],

  // Go 文件（如需要请取消注释）| Go files (uncomment if needed)
  // '*.go': [
  //   // Go 格式化 | Go formatting
  //   'gofmt -w',
  //   'golint',
  // ],
}

// 高级配置示例（如需要可以替换上面的配置）| Advanced configuration example (can replace above config if needed)
// module.exports = async (stagedFiles) => {
//   const commands = [];
//
//   // 动态生成命令基于文件类型 | Dynamically generate commands based on file types
//   const jsFiles = stagedFiles.filter(file => file.match(/\.[jt]sx?$/));
//   if (jsFiles.length > 0) {
//     commands.push(`eslint --fix ${jsFiles.join(' ')}`);
//     commands.push(`prettier --write ${jsFiles.join(' ')}`);
//   }
//
//   const cssFiles = stagedFiles.filter(file => file.match(/\.(css|scss|less)$/));
//   if (cssFiles.length > 0) {
//     commands.push(`prettier --write ${cssFiles.join(' ')}`);
//   }
//
//   return commands;
// };

// 性能优化建议 | Performance optimization tips:
// 1. 避免在 lint-staged 中运行 tsc，因为它会检查整个项目 | Avoid running tsc in lint-staged as it checks the entire project
// 2. 使用 --cache 选项加速 ESLint | Use --cache option to speed up ESLint
// 3. 考虑并行运行命令 | Consider running commands in parallel
// 4. 只运行必要的命令 | Only run necessary commands
EOF

# Update TypeScript config if needed
echo ""
echo "📝 Ensuring TypeScript strict configuration..."
cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    // 编译目标 | Compilation target
    "target": "ES2017",
    // 指定 ECMAScript 目标版本 | Specify ECMAScript target version
    // ES3, ES5, ES6/ES2015, ES2016, ES2017, ES2018, ES2019, ES2020, ESNext

    // 库文件 | Library files
    "lib": ["dom", "dom.iterable", "esnext"],
    // 编译时包含的库文件 | Library files to include in compilation
    // dom: DOM API, esnext: 最新 ES 特性 | DOM API, esnext: latest ES features

    // JavaScript 支持 | JavaScript support
    "allowJs": true,
    // 允许编译 JavaScript 文件 | Allow compiling JavaScript files

    // 跳过库检查 | Skip library check
    "skipLibCheck": true,
    // 跳过声明文件的类型检查 | Skip type checking of declaration files

    // 严格模式配置 | Strict mode configuration
    "strict": true,
    // 启用所有严格类型检查选项 | Enable all strict type checking options

    // 严格模式详细选项（已被 strict: true 包含）| Detailed strict options (included by strict: true)
    // "noImplicitAny": true,                    // 不允许隐式 any 类型 | Disallow implicit any types
    // "strictNullChecks": true,                 // 严格的 null 检查 | Strict null checks
    // "strictFunctionTypes": true,              // 严格的函数类型检查 | Strict function types
    // "strictBindCallApply": true,              // 严格的 bind/call/apply 检查 | Strict bind/call/apply
    // "strictPropertyInitialization": true,     // 严格的属性初始化检查 | Strict property initialization
    // "noImplicitThis": true,                   // 不允许隐式 this | Disallow implicit this
    // "useUnknownInCatchVariables": true,       // catch 变量默认为 unknown | Catch variables default to unknown
    // "alwaysStrict": true,                     // 始终使用严格模式 | Always use strict mode

    // 额外的类型检查选项 | Additional type checking options
    "noUnusedLocals": true, // 报告未使用的局部变量 | Report unused local variables
    "noUnusedParameters": true, // 报告未使用的参数 | Report unused parameters
    "noImplicitReturns": true, // 函数的所有路径都必须有返回值 | All code paths must return
    "noFallthroughCasesInSwitch": true, // switch 语句必须有 break | Switch must have break
    "noUncheckedIndexedAccess": true, // 索引访问返回 undefined 联合类型 | Index access includes undefined
    "noImplicitOverride": true, // 重写方法必须使用 override | Override methods must use override
    "noPropertyAccessFromIndexSignature": false, // 通过索引访问必须使用括号 | Index access must use brackets
    // "exactOptionalPropertyTypes": true,        // 精确的可选属性类型（如需要请取消注释）| Exact optional property types (uncomment if needed)

    // 输出配置 | Output configuration
    "noEmit": true,
    // 不生成输出文件（Next.js 自行处理）| Don't emit output files (Next.js handles this)

    // 模块解析配置 | Module resolution configuration
    "esModuleInterop": true,
    // 启用 ES 模块互操作性 | Enable ES module interoperability

    "module": "esnext",
    // 模块代码生成方式 | Module code generation

    "moduleResolution": "bundler",
    // 模块解析策略 | Module resolution strategy
    // node: Node.js 风格, bundler: 打包工具风格 | node: Node.js style, bundler: bundler style

    "resolveJsonModule": true,
    // 允许导入 JSON 文件 | Allow importing JSON files

    "isolatedModules": true,
    // 将每个文件作为单独的模块 | Treat each file as separate module

    // JSX 配置 | JSX configuration
    "jsx": "preserve",
    // JSX 代码生成方式 | JSX code generation
    // preserve: 保留 JSX, react: 转换为 React.createElement | preserve: keep JSX, react: transform to React.createElement

    // 编译优化 | Compilation optimization
    "incremental": true,
    // 启用增量编译 | Enable incremental compilation

    "forceConsistentCasingInFileNames": true,
    // 强制文件名大小写一致 | Force consistent file name casing

    // 插件配置 | Plugin configuration
    "plugins": [
      {
        "name": "next"
        // Next.js TypeScript 插件 | Next.js TypeScript plugin
      }
    ],

    // 路径别名配置 | Path alias configuration
    "paths": {
      "@/*": ["./src/*"]
      // @ 符号指向 src 目录 | @ symbol points to src directory
    }

    // 其他有用的配置选项（根据需要取消注释）| Other useful options (uncomment as needed)
    // "baseUrl": "./",                          // 基础目录 | Base directory
    // "rootDir": "./src",                       // 根目录 | Root directory
    // "outDir": "./dist",                       // 输出目录 | Output directory
    // "declaration": true,                      // 生成声明文件 | Generate declaration files
    // "declarationMap": true,                   // 生成声明文件的 source map | Generate declaration source maps
    // "sourceMap": true,                        // 生成 source map | Generate source maps
    // "removeComments": true,                   // 删除注释 | Remove comments
    // "downlevelIteration": true,               // 降级迭代器 | Downlevel iteration
    // "importHelpers": true,                    // 从 tslib 导入辅助函数 | Import helpers from tslib
    // "experimentalDecorators": true,           // 启用装饰器 | Enable decorators
    // "emitDecoratorMetadata": true,           // 发射装饰器元数据 | Emit decorator metadata
    // "allowSyntheticDefaultImports": true,     // 允许合成默认导入 | Allow synthetic default imports
    // "preserveSymlinks": true,                 // 保留符号链接 | Preserve symlinks
    // "allowUmdGlobalAccess": true,            // 允许访问 UMD 全局变量 | Allow UMD global access
    // "listEmittedFiles": true,                 // 列出生成的文件 | List emitted files
    // "listFiles": true,                        // 列出编译的文件 | List compiled files
    // "disableSizeLimit": true,                 // 禁用大小限制 | Disable size limit
    // "preserveConstEnums": true,               // 保留 const enum | Preserve const enums
    // "preserveValueImports": true,             // 保留值导入 | Preserve value imports
    // "verbatimModuleSyntax": true,            // 逐字模块语法 | Verbatim module syntax
  },

  // 包含的文件 | Files to include
  "include": [
    "next-env.d.ts", // Next.js 环境类型定义 | Next.js environment type definitions
    "**/*.ts", // 所有 TypeScript 文件 | All TypeScript files
    "**/*.tsx", // 所有 TypeScript React 文件 | All TypeScript React files
    ".next/types/**/*.ts" // Next.js 生成的类型 | Next.js generated types
  ],

  // 排除的文件 | Files to exclude
  "exclude": [
    "node_modules" // 依赖目录 | Dependencies directory
    // "dist",                 // 输出目录（如需要请取消注释）| Output directory (uncomment if needed)
    // "build",                // 构建目录（如需要请取消注释）| Build directory (uncomment if needed)
    // "coverage",             // 测试覆盖率（如需要请取消注释）| Test coverage (uncomment if needed)
    // "**/*.spec.ts",         // 测试文件（如需要请取消注释）| Test files (uncomment if needed)
    // "**/*.test.ts"          // 测试文件（如需要请取消注释）| Test files (uncomment if needed)
  ]

  // 继承配置（如需要请取消注释）| Extends configuration (uncomment if needed)
  // "extends": "@tsconfig/recommended/tsconfig.json"

  // TypeScript 引用项目配置（如需要请取消注释）| TypeScript project references (uncomment if needed)
  // "references": [
  //   { "path": "./tsconfig.node.json" }
  // ]
}
EOF

# Update package.json scripts
echo ""
echo "📝 Updating package.json scripts..."

#!/bin/bash

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "Error: package.json not found!"
    exit 1
fi

# Create a backup
cp package.json package.json.bak

# Use awk to process the file
awk '
BEGIN {
    in_scripts = 0
    last_script_line = ""
}
/"scripts": {/ {
    print
    in_scripts = 1
    next
}
in_scripts && /^  }/ {
    # Found the end of scripts section
    # Print the last script line with a comma added at the end
    if (last_script_line != "") {
        sub(/"$/, "\",", last_script_line)
        print last_script_line
    }

    # Add new scripts
    print "    \"lint\": \"eslint . --ext .ts,.tsx,.js,.jsx --max-warnings 0\","
    print "    \"lint:fix\": \"eslint . --ext .ts,.tsx,.js,.jsx --fix --max-warnings 0\","
    print "    \"format\": \"prettier --write .\","
    print "    \"format:check\": \"prettier --check .\","
    print "    \"typecheck\": \"tsc --noEmit\","
    print "    \"quality\": \"bun run lint && bun run format:check && bun run typecheck\","
    print "    \"quality:fix\": \"bun run lint:fix && bun run format && bun run typecheck\","
    print "    \"prepare\": \"husky\""

    # Print the closing brace
    print $0
    in_scripts = 0
    next
}
in_scripts && /^    "/ {
    # This is a script line
    if (last_script_line != "") {
        print last_script_line
    }
    last_script_line = $0
    next
}
{
    print
}
' package.json > package.json.tmp

# Check if awk succeeded
if [ $? -eq 0 ]; then
    mv package.json.tmp package.json
    rm -f package.json.bak
    echo "✅ Scripts added successfully to package.json"
else
    echo "Error: Failed to process package.json"
    mv -f package.json.bak package.json
    rm -f package.json.tmp
    exit 1
fi

# Initialize Husky
echo ""
echo "🐶 Initializing Husky..."
bunx husky init

# Create pre-commit hook
echo ""
echo "📝 Creating pre-commit hook..."
cat > .husky/pre-commit << 'EOF'
# Husky pre-commit hook
# 在 git commit 前执行，运行 lint-staged | Runs before git commit, executes lint-staged

# 运行 lint-staged | Run lint-staged
# lint-staged 会根据 .lintstagedrc.js 配置检查暂存的文件 | lint-staged checks staged files based on .lintstagedrc.js config
bunx lint-staged

# 如果 lint-staged 失败，提交将被中止 | If lint-staged fails, commit will be aborted
# 退出码会自动传递 | Exit code is automatically passed through
EOF
chmod +x .husky/pre-commit

# Create commit-msg hook
echo ""
echo "📝 Creating commit-msg hook..."
cat > .husky/commit-msg << 'EOF'
# Husky commit-msg hook
# 在 git commit 消息创建后执行，验证提交信息格式 | Runs after commit message is created, validates commit message format

# 运行 commitlint 检查提交信息 | Run commitlint to check commit message
# $1 是包含提交信息的临时文件路径 | $1 is the temporary file path containing commit message
bunx commitlint --edit "$1"

# 如果提交信息不符合规范，提交将被中止 | If commit message doesn't meet standards, commit will be aborted
# commitlint 会根据 commitlint.config.js 的规则进行检查 | commitlint checks based on rules in commitlint.config.js

# 提交信息格式示例 | Commit message format examples:
# feat(auth): add login functionality
# fix(ui): resolve button alignment issue
# docs: update README with new API endpoints
# style(components): format code with prettier
# refactor(utils): simplify date formatting logic
EOF
chmod +x .husky/commit-msg

#!/bin/bash

# claude.sh - Script to generate CLAUDE.md file for Claude Code guidance

cat > CLAUDE.md << 'EOF'
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

```bash
# Development
bun dev                    # Start development server (primary)
bun dev:turbo             # Start with Turbopack for faster builds

# Code Quality
bun run lint              # Run ESLint with max warnings = 0
bun run lint:fix          # Auto-fix ESLint issues
bun run format            # Format code with Prettier
bun run format:check      # Check formatting without changes
bun run typecheck         # Run TypeScript type checking
bun run quality           # Run all checks: lint + format:check + typecheck
bun run quality:fix       # Fix issues and run checks: lint:fix + format + typecheck

# Production
bun run build             # Create production build
bun run build:turbo       # Production build with Turbopack
bun start                 # Start production server
```

## Architecture Overview

This is a Next.js latest application using the App Router pattern with TypeScript, Tailwind CSS, and shadcn/ui components. The project is configured for Supabase integration and uses Drizzle ORM for database operations.

### Key Directories
- `src/app/` - Next.js App Router pages and layouts
- `src/components/ui/` - shadcn/ui components (45+ pre-built components)
- `src/lib/` - Utilities and providers (theme, utils)
- `src/hooks/` - Custom React hooks

### Technology Stack
- **Framework**: Next.js with App Router
- **Language**: TypeScript with strict mode
- **Styling**: Tailwind CSS with CSS variables
- **UI Library**: shadcn/ui (New York style)
- **Database**: Supabase with Drizzle ORM
- **Forms**: React Hook Form + Zod validation
- **Dark Mode**: next-themes provider

## Code Standards

### Formatting Rules (enforced via Prettier)
- Line width: 80 characters
- Indentation: 2 spaces
- No semicolons
- Double quotes
- Trailing commas (ES5)

### TypeScript Configuration
- Strict mode enabled with all safety checks
- Path alias: `@/*` maps to `./src/*`
- No unused locals, parameters, or imports allowed
- Exact optional property types enforced

### Git Workflow
- Pre-commit hooks run lint-staged (ESLint fix + Prettier)
- Commit messages must follow Angular convention (enforced by commitlint)
- Valid commit types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert

### Component Patterns
- Use existing shadcn/ui components from `src/components/ui/`
- Follow the established component structure when creating new components
- Utilize the `cn()` utility from `src/lib/utils.ts` for className merging
- Components support dark mode via CSS variables

## Important Notes
- Primary package manager is Bun, but npm/yarn/pnpm are also configured
- No test framework is currently set up
- Font optimization uses Geist font family via next/font
- All linting must pass with zero warnings for commits to succeed

## Task Completion Requirements
- After completing any task, ALWAYS run `bun run quality:fix` first to auto-fix any issues
- Then run `bun run quality` to ensure all checks pass
- Only proceed with commits after both commands succeed without errors
- When generating commit messages, DO NOT include any machine-generated suffixes or indicators

## Git Commit Rules

- NEVER include machine-generated suffixes or indicators in commit messages
- Do NOT add "🤖 Generated with Claude Code" or similar markers
- Do NOT add "Co-Authored-By: Claude" or any bot attribution
- Keep commit messages clean and professional without any automation indicators
EOF

echo "CLAUDE.md has been generated successfully!"

cat > README.md << 'EOF'
# TOPCODER FULLSTACK

## How to Run

### Development
```bash
bun dev
```

### Production
```bash
bun run build
bun start
```

### Code Quality
```bash
bun run quality
```
EOF

echo "README.md has been created successfully!"


# Run initial quality check
echo ""
echo "🔍 Running initial quality check..."

bun run quality:fix || true

git add .
git commit -m "init: topcoderfullstack project initialization"

echo ""
echo "✅ Quality assurance tools setup completed!"
echo ""
echo "📋 Available commands:"
echo "  bun run dev          - Start development server"
echo "  bun run build        - Build for production"
echo "  bun run quality      - Run all quality checks"
echo "  bun run quality:fix  - Fix all auto-fixable issues"
echo "  bun run lint         - Run ESLint"
echo "  bun run format       - Format code with Prettier"
echo "  bun run typecheck    - Run TypeScript type checking"
echo ""
echo "🎯 Git hooks installed:"
echo "  pre-commit  - Runs lint-staged (ESLint + Prettier)"
echo "  commit-msg  - Validates commit message format"
echo ""
echo "💡 Commit message format: <type>(<scope>): <subject>"
echo "   Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert"
echo ""
echo "🚀 You're all set! Happy coding!"
