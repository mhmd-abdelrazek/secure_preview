#ifndef NOMINMAX
#define NOMINMAX
#endif

#include "secure_preview_plugin.h"

#include <flutter/standard_method_codec.h>
#include <tlhelp32.h>

#if defined(_M_X64) || defined(_M_IX86)
#include <intrin.h>
#endif

#include <algorithm>
#include <cwctype>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

#ifndef WDA_EXCLUDEFROMCAPTURE
// Windows 10 version 2004+. Older headers do not define it.
#define WDA_EXCLUDEFROMCAPTURE 0x00000011
#endif

namespace secure_preview {

namespace {

std::wstring ToLower(std::wstring s) {
  std::transform(s.begin(), s.end(), s.begin(),
                 [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
  return s;
}

bool ContainsAny(const std::wstring &haystack,
                 const std::vector<std::wstring> &needles) {
  const std::wstring lower = ToLower(haystack);
  for (const auto &n : needles) {
    if (lower.find(n) != std::wstring::npos) return true;
  }
  return false;
}

// Case-insensitive check whether any process with one of [names] is running.
bool AnyProcessRunning(const std::vector<std::wstring> &names) {
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) return false;

  PROCESSENTRY32W entry;
  entry.dwSize = sizeof(entry);
  bool found = false;
  if (Process32FirstW(snapshot, &entry)) {
    do {
      const std::wstring exe = ToLower(entry.szExeFile);
      if (std::find(names.begin(), names.end(), exe) != names.end()) {
        found = true;
        break;
      }
    } while (Process32NextW(snapshot, &entry));
  }
  CloseHandle(snapshot);
  return found;
}

std::wstring ReadBiosString(const wchar_t *value_name) {
  wchar_t buffer[256] = {0};
  DWORD size = sizeof(buffer);
  if (RegGetValueW(HKEY_LOCAL_MACHINE, L"HARDWARE\\DESCRIPTION\\System\\BIOS",
                   value_name, RRF_RT_REG_SZ, nullptr, buffer,
                   &size) == ERROR_SUCCESS) {
    return buffer;
  }
  return L"";
}

// Hypervisor vendor from CPUID, or empty when none is reported.
std::string HypervisorVendor() {
#if defined(_M_X64) || defined(_M_IX86)
  int regs[4] = {0};
  __cpuid(regs, 1);
  if ((regs[2] & (1 << 31)) == 0) return "";
  __cpuid(regs, 0x40000000);
  char vendor[13] = {0};
  std::memcpy(vendor, &regs[1], 4);
  std::memcpy(vendor + 4, &regs[2], 4);
  std::memcpy(vendor + 8, &regs[3], 4);
  return vendor;
#else
  return "";
#endif
}

// Heuristic virtual-machine detection.
//
// "Microsoft Hv" alone is NOT treated as a VM: a normal Windows 11 host with
// virtualization-based security or Hyper-V enabled reports it too. Hyper-V
// guests are caught through the BIOS product name instead.
bool IsVirtualMachine() {
  const std::string vendor = HypervisorVendor();
  if (!vendor.empty() && vendor != "Microsoft Hv") return true;

  const std::wstring identity =
      ReadBiosString(L"SystemManufacturer") + L" " +
      ReadBiosString(L"SystemProductName");
  return ContainsAny(identity, {L"vmware", L"virtualbox", L"innotek", L"qemu",
                                L"kvm", L"xen", L"parallels", L"bochs",
                                L"virtual machine"});
}

// Known screen recorders / broadcasters. A name match is a heuristic and is
// trivial to evade by renaming the executable.
bool IsRecorderRunning() {
  return AnyProcessRunning({
      L"obs64.exe", L"obs32.exe", L"obs.exe", L"streamlabs obs.exe",
      L"bdcam.exe", L"camtasiastudio.exe", L"camrecorder.exe", L"sharex.exe",
      L"screentogif.exe", L"loom.exe",
  });
}

flutter::EncodableValue Key(const char *name) {
  return flutter::EncodableValue(std::string(name));
}

}  // namespace

// static
void SecurePreviewPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "secure_preview",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<SecurePreviewPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

SecurePreviewPlugin::SecurePreviewPlugin(
    flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {}

SecurePreviewPlugin::~SecurePreviewPlugin() {
  if (protected_window_ != nullptr && IsWindow(protected_window_)) {
    SetWindowDisplayAffinity(protected_window_, WDA_NONE);
  }
  protected_window_ = nullptr;
}

HWND SecurePreviewPlugin::GetTopLevelWindow() const {
  auto *view = registrar_->GetView();
  if (view == nullptr) return nullptr;
  HWND child = view->GetNativeWindow();
  if (child == nullptr) return nullptr;
  return GetAncestor(child, GA_ROOT);
}

bool SecurePreviewPlugin::SetCaptureProtection(bool enabled) {
  if (!enabled) {
    HWND hwnd = protected_window_ != nullptr ? protected_window_
                                             : GetTopLevelWindow();
    protected_window_ = nullptr;
    if (hwnd == nullptr || !IsWindow(hwnd)) return false;
    return SetWindowDisplayAffinity(hwnd, WDA_NONE) != FALSE;
  }

  HWND hwnd = GetTopLevelWindow();
  if (hwnd == nullptr) return false;

  // Preferred: the window disappears from captures (Windows 10 2004+).
  // Fallback for older builds: the window is captured as a black rectangle.
  if (SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE) ||
      SetWindowDisplayAffinity(hwnd, WDA_MONITOR)) {
    protected_window_ = hwnd;
    return true;
  }
  return false;
}

void SecurePreviewPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string &method = method_call.method_name();

  if (method == "setScreenshotProtection") {
    bool enabled = true;
    if (const auto *arg = std::get_if<bool>(method_call.arguments())) {
      enabled = *arg;
    }
    result->Success(flutter::EncodableValue(SetCaptureProtection(enabled)));
    return;
  }

  if (method == "checkSecurity") {
    // Windows has no direct equivalents for "rooted" or "developerOptions".
    const bool emulator = IsVirtualMachine();
    const bool debuggerAttached = IsDebuggerPresent() != FALSE;
    const bool remoteSession = GetSystemMetrics(SM_REMOTESESSION) != 0;
    const bool recorder = IsRecorderRunning();
    const bool externalDisplay = GetSystemMetrics(SM_CMONITORS) > 1;

    flutter::EncodableMap map;
    map[Key("rooted")] = flutter::EncodableValue(false);
    map[Key("emulator")] = flutter::EncodableValue(emulator);
    map[Key("developerOptions")] = flutter::EncodableValue(false);
    // Mapped to "a native debugger is attached to this process".
    map[Key("usbDebugging")] = flutter::EncodableValue(debuggerAttached);
    // Mapped to "running inside a Remote Desktop session".
    map[Key("screenMirroring")] = flutter::EncodableValue(remoteSession);
    map[Key("screenRecording")] = flutter::EncodableValue(recorder);
    map[Key("externalDisplay")] = flutter::EncodableValue(externalDisplay);
    result->Success(flutter::EncodableValue(map));
    return;
  }

  result->NotImplemented();
}

}  // namespace secure_preview
