<div align="center">

![App Network Controller](https://capsule-render.vercel.app/api?type=waving&color=0:0a1628,25:1e3a5f,50:0ea5e9,75:38bdf8,100:7dd3fc&height=220&section=header&text=App%20Network%20Controller&fontSize=50&fontColor=ffffff&fontAlignY=35&desc=%F0%9F%9B%A1%EF%B8%8F%20%D8%AA%D8%AD%D9%83%D9%85%20%D9%83%D8%A7%D9%85%D9%84%20%D8%A8%D8%A7%D9%84%D8%A8%D8%B1%D8%A7%D9%85%D8%AC%20%E2%80%A2%20%D8%AD%D8%B8%D8%B1%20%D8%A7%D9%84%D8%A7%D9%86%D8%AA%D8%B1%D9%86%D8%AA%20%E2%80%A2%20%D9%88%D8%A7%D8%AC%D9%87%D8%A9%20%D8%B1%D8%B3%D9%88%D9%85%D9%8A%D8%A9&descAlignY=58&descAlign=50)

[![Version](https://img.shields.io/badge/%F0%9F%94%96_Version-2.0-0ea5e9?style=for-the-badge&logoColor=white)](#)
[![PowerShell](https://img.shields.io/badge/%E2%9A%99%EF%B8%8F_PowerShell-5.1+-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](#-المتطلبات)
[![Windows](https://img.shields.io/badge/%F0%9F%96%A5%EF%B8%8F_Windows-10%2F11-0078D4?style=for-the-badge&logo=windows&logoColor=white)](#-المتطلبات)
[![WPF](https://img.shields.io/badge/%F0%9F%8E%A8_GUI-WPF%20Dark%20Theme-38bdf8?style=for-the-badge&logoColor=white)](#-المميزات)
[![Falcon01](https://img.shields.io/badge/%F0%9F%A6%85_Falcon01-Developer-1e3a5f?style=for-the-badge&logoColor=white)](https://github.com/F2lcon01)

<br>

### التشغيل السريع

```powershell
powershell -ExecutionPolicy Bypass -File "AppNetworkController.ps1"
```

او دبل كلك على `AppNetworkController.bat`

<br>

</div>

---

## الفهرس

| # | القسم | الوصف |
|:-:|-------|-------|
| 1 | [نظرة عامة](#-نظرة-عامة) | ايش يسوي البرنامج ولمن |
| 2 | [المميزات](#-المميزات) | كل الخصائص بالتفصيل |
| 3 | [طريقة التشغيل](#-طريقة-التشغيل) | خطوات التثبيت والتشغيل |
| 4 | [شرح الواجهة](#-شرح-الواجهة) | شرح كل قسم في البرنامج |
| 5 | [البنية التقنية](#-البنية-التقنية) | كيف يشتغل البرنامج من الداخل |
| 6 | [المتطلبات](#-المتطلبات) | ايش تحتاج عشان يشتغل |
| 7 | [الملفات](#-الملفات) | شرح كل ملف في المشروع |

---

<div align="center">

## نظرة عامة

</div>

> **App Network Controller** برنامج يتحكم بوصول البرامج للإنترنت عن طريق قواعد Windows Firewall.
> بضغطة زر تقدر تحظر أي برنامج من الاتصال بالإنترنت — أو تلغي الحظر.

```
  ┌─────────────────────────────────────────────────────────────────┐
  │                                                                 │
  │   🛡️  App Network Controller v2.0                              │
  │                                                                 │
  │   ✅  حظر البرامج من الإنترنت بنقرة واحدة                      │
  │   ✅  واجهة رسومية حديثة (Dark Theme)                           │
  │   ✅  كشف البرامج المثبتة تلقائياً من Registry                  │
  │   ✅  تصدير واستيراد قواعد الحظر (JSON)                         │
  │   ✅  سجل عمليات كامل (Log)                                     │
  │   ✅  يطلب صلاحيات المسؤول تلقائياً                             │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘
```

> [!TIP]
> البرنامج مفيد جداً لحظر البرامج بعد تثبيتها — مثل منع التطبيقات من إرسال بيانات أو التحديث التلقائي.

---

<div align="center">

## المميزات

</div>

---

<div align="center">

### 1️⃣ حظر البرامج الشغالة — Running Apps

</div>

> عرض جميع البرامج الشغالة حالياً مع حالة كل برنامج (محظور / مسموح):

```
  ┌──────────────────────────────────────────────────────────────┐
  │  📋 Running Apps                                             │
  │                                                              │
  │  Name              Path                        Status        │
  │  ─────────────     ───────────────────────     ──────        │
  │  chrome            C:\Program Files\Google..   🟢 Allowed    │
  │  discord           C:\Users\...\Discord..      🔴 Blocked    │
  │  spotify           C:\Users\...\Spotify..      🟢 Allowed    │
  │                                                              │
  │  🔄 Refresh    🔍 Search: [_______________]                  │
  │                                                              │
  │  📌 دبل كلك على أي برنامج = حظر / إلغاء حظر                │
  │  📌 كلك يمين = قائمة الخيارات                                │
  └──────────────────────────────────────────────────────────────┘
```

> [!NOTE]
> البرامج النظامية (مثل `svchost`, `explorer`, `lsass`) محمية ولا يمكن حظرها.

---

<div align="center">

### 2️⃣ كشف البرامج المثبتة — Installed Apps

</div>

> يفحص الـ Registry ويعرض كل البرامج المثبتة على الجهاز — حتى لو مو شغالة حالياً:

```
  📡  مصادر الكشف:
      ├── HKLM\SOFTWARE\...\Uninstall         → البرامج 64-bit
      ├── HKLM\SOFTWARE\WOW6432Node\...\      → البرامج 32-bit
      └── HKCU\SOFTWARE\...\Uninstall         → برامج المستخدم الحالي
```

> [!TIP]
> اضغط **Scan** لفحص البرامج المثبتة. الفحص يأخذ لحظات لأنه يمر على كل الـ Registry.

---

<div align="center">

### 3️⃣ إدارة البرامج المحظورة — Blocked Apps

</div>

> عرض جميع قواعد الحظر الموجودة مع إمكانية:

```
  ┌──────────────────────────────────────────────────────────────┐
  │  🚫 Blocked Apps                                             │
  │                                                              │
  │  🔄 Refresh   ✅ Unblock All   📤 Export   📥 Import        │
  │                                                              │
  │  Name         Path                  Direction    Rule        │
  │  ─────        ────                  ─────────    ────        │
  │  discord      C:\...\discord.exe    Outbound     AppBlocker_ │
  │  discord      C:\...\discord.exe    Inbound      AppBlocker_ │
  │                                                              │
  │  📌 دبل كلك = إلغاء حظر مع تأكيد                           │
  └──────────────────────────────────────────────────────────────┘
```

> [!IMPORTANT]
> - **Export** — يحفظ كل القواعد في ملف JSON (للنقل لجهاز ثاني)
> - **Import** — يستورد قواعد من ملف JSON ويطبقها
> - **Unblock All** — يزيل كل قواعد الحظر دفعة واحدة (مع تأكيد)

---

<div align="center">

### 4️⃣ حظر بالمسار — Block by Path

</div>

> حظر أي ملف `.exe` مباشرة عن طريق المسار أو زر Browse:

```
  ┌──────────────────────────────────────────────────────────────┐
  │  📂 Block by Path                                            │
  │                                                              │
  │  المسار: [C:\Program Files\App\app.exe    ] [Browse...]      │
  │                                                              │
  │  الاسم المكتشف: app                                          │
  │                                                              │
  │  [🚫 Block This Application]                                 │
  │                                                              │
  │  ─── Recent Blocks ───                                       │
  │  app1    C:\...\app1.exe                                     │
  │  app2    C:\...\app2.exe                                     │
  └──────────────────────────────────────────────────────────────┘
```

> [!TIP]
> مفيد لحظر برامج مو شغالة حالياً وما تظهر في Running Apps — اختر الملف مباشرة.

---

<div align="center">

### 5️⃣ سجل العمليات — Logs

</div>

> كل عملية حظر أو إلغاء حظر تُسجّل مع الوقت والتاريخ:

```
  [2026-04-08 05:51:02] === App Network Controller v2.0 started ===
  [2026-04-08 05:51:15] BLOCKED | chrome | C:\...\chrome.exe
  [2026-04-08 05:52:03] UNBLOCKED | chrome | 2 rules
  [2026-04-08 05:53:00] EXPORTED | 4 rules to backup.json
```

---

<div align="center">

### 6️⃣ الإعدادات — Settings

</div>

> - تصدير واستيراد القواعد
> - عرض قائمة العمليات النظامية المحمية
> - معلومات عن البرنامج

---

<div align="center">

## طريقة التشغيل

</div>

---

<div align="center">

### الطريقة 1 — دبل كلك (الأسهل)

</div>

```
  🟡 الخطوة 1 ──→  دبل كلك على AppNetworkController.bat
  
  🟡 الخطوة 2 ──→  تظهر نافذة UAC — اضغط Yes (نعم)
  
  🟢 النتيجة  ──→  البرنامج يفتح بواجهة رسومية مباشرة
```

---

<div align="center">

### الطريقة 2 — من Terminal

</div>

```powershell
powershell -ExecutionPolicy Bypass -File "AppNetworkController.ps1"
```

> [!WARNING]
> البرنامج يحتاج **صلاحيات المسؤول (Administrator)** — إذا شغلته بدون صلاحيات، يطلبها تلقائياً عبر نافذة UAC.

---

<div align="center">

## شرح الواجهة

</div>

> الواجهة مقسمة لعدة أجزاء رئيسية:

```
  ┌──────────────────────────────────────────────────────────────┐
  │  🛡️ App Network Controller v2.0                    🟢 Ready │
  ├───────────────┬──────────────────────────────────────────────┤
  │               │                                              │
  │  📋 Running   │     [ محتوى القسم المختار ]                  │
  │  💿 Installed │                                              │
  │  🚫 Blocked   │     DataGrid مع البيانات                     │
  │  📂 By Path   │     + أزرار التحكم                           │
  │  📊 Logs      │     + خانة البحث                             │
  │  ⚙️ Settings  │                                              │
  │               │                                              │
  ├───────────────┴──────────────────────────────────────────────┤
  │  Ready                                            05:51:02   │
  └──────────────────────────────────────────────────────────────┘
```

| القسم | الوظيفة | طريقة الاستخدام |
|-------|---------|----------------|
| **📋 Running Apps** | البرامج الشغالة حالياً | دبل كلك لحظر/إلغاء حظر |
| **💿 Installed Apps** | كل البرامج المثبتة | اضغط Scan ثم دبل كلك |
| **🚫 Blocked Apps** | القواعد المحظورة | دبل كلك لإلغاء حظر + Export/Import |
| **📂 Block by Path** | حظر بمسار الملف | Browse واختر الملف ثم Block |
| **📊 Logs** | سجل العمليات | Refresh لتحديث + Clear لمسح |
| **⚙️ Settings** | إعدادات وتصدير | Export/Import + عرض Whitelist |

> [!TIP]
> **البحث**: كل تبويب فيه خانة بحث — اكتب اسم البرنامج وتتصفى القائمة فوراً.

---

<div align="center">

## البنية التقنية

</div>

```mermaid
graph TD
    A[المستخدم يشغل البرنامج] --> B{صلاحيات Admin?}
    B -->|لا| C[طلب UAC تلقائي]
    C --> B
    B -->|نعم| D[تحميل WPF GUI]
    D --> E[عرض البرامج الشغالة]
    
    E --> F{اختيار المستخدم}
    F -->|حظر| G[إنشاء Firewall Rule]
    F -->|إلغاء حظر| H[حذف Firewall Rule]
    F -->|تصدير| I[حفظ JSON]
    F -->|استيراد| J[قراءة JSON + إنشاء Rules]
    
    G --> K[Inbound + Outbound Block]
    K --> L[تسجيل في Log]
    H --> L
    I --> L
    J --> L

    style A fill:#0ea5e9,stroke:#0369a1,color:#fff
    style B fill:#f59e0b,stroke:#b45309,color:#fff
    style C fill:#f59e0b,stroke:#b45309,color:#fff
    style D fill:#22c55e,stroke:#15803d,color:#fff
    style E fill:#38bdf8,stroke:#0284c7,color:#fff
    style F fill:#533483,stroke:#3A1F6E,color:#fff
    style G fill:#ef4444,stroke:#dc2626,color:#fff
    style H fill:#22c55e,stroke:#15803d,color:#fff
    style I fill:#0ea5e9,stroke:#0369a1,color:#fff
    style J fill:#0ea5e9,stroke:#0369a1,color:#fff
    style K fill:#ef4444,stroke:#dc2626,color:#fff
    style L fill:#10b981,stroke:#059669,color:#fff
```

> [!NOTE]
> كل عملية حظر تنشئ **قاعدتين** في Windows Firewall — واحدة Inbound وواحدة Outbound — لضمان حظر كامل.

---

<div align="center">

## المتطلبات

</div>

| المتطلب | التفاصيل |
|---------|----------|
| ![](https://img.shields.io/badge/-Windows%2010%2F11-0078D4?style=flat-square&logo=windows&logoColor=white) | Windows 10 أو Windows 11 |
| ![](https://img.shields.io/badge/-PowerShell%205.1+-5391FE?style=flat-square&logo=powershell&logoColor=white) | مثبت مسبقاً مع Windows |
| ![](https://img.shields.io/badge/-Administrator-ef4444?style=flat-square&logoColor=white) | صلاحيات المسؤول (يطلبها تلقائياً) |
| ![](https://img.shields.io/badge/-WPF%20/.NET-512BD4?style=flat-square&logo=dotnet&logoColor=white) | مثبت مسبقاً مع Windows |

> [!IMPORTANT]
> لا يحتاج تثبيت أي شيء إضافي — كل المتطلبات موجودة مع Windows.

---

<div align="center">

## الملفات

</div>

| الملف | الوظيفة | طريقة التشغيل |
|-------|---------|--------------|
| `AppNetworkController.ps1` | البرنامج الرئيسي — واجهة رسومية كاملة | `powershell -ExecutionPolicy Bypass -File "AppNetworkController.ps1"` |
| `AppNetworkController.bat` | ملف تشغيل سريع — دبل كلك | **دبل كلك** على الملف مباشرة |

```
  📁 Block-apps-internet/
      ├── AppNetworkController.ps1    ← البرنامج الرئيسي (واجهة + محرك)
      ├── AppNetworkController.bat    ← لانشر للتشغيل السريع
      └── README.md                   ← هذا الملف
```

> [!CAUTION]
> لا تحذف ملف `.ps1` — ملف `.bat` يعتمد عليه للتشغيل.

---

<div align="center">

### كيف يحظر البرنامج؟

</div>

```
  🔴 الحظر:
      New-NetFirewallRule → AppBlocker_AppName_OUT (Outbound Block)
      New-NetFirewallRule → AppBlocker_AppName_IN  (Inbound Block)

  🟢 إلغاء الحظر:
      Remove-NetFirewallRule → AppBlocker_AppName_OUT
      Remove-NetFirewallRule → AppBlocker_AppName_IN
```

> جميع القواعد تبدأ بالبادئة `AppBlocker_` — سهلة التعرف عليها في Windows Firewall.

---

<div align="center">

**App Network Controller v2.0** — بقلم Falcon (fox01vip@gmail.com)

[![GitHub](https://img.shields.io/badge/GitHub-F2lcon01-1e3a5f?style=for-the-badge&logo=github&logoColor=white)](https://github.com/F2lcon01)

![Footer](https://capsule-render.vercel.app/api?type=waving&color=0:7dd3fc,50:0ea5e9,100:0a1628&height=100&section=footer)

</div>
