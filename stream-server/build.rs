//! Build script for compiling Swift ScreenCaptureKit bridge

use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    // Only build Swift on macOS
    #[cfg(target_os = "macos")]
    {
        build_swift_bridge();
    }
}

#[cfg(target_os = "macos")]
fn build_swift_bridge() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let swift_dir = manifest_dir.join("swift");

    println!("cargo:rerun-if-changed=swift/");

    // Get target architecture
    let target_arch = env::var("CARGO_CFG_TARGET_ARCH").unwrap_or_else(|_| "arm64".to_string());
    let swift_arch = match target_arch.as_str() {
        "aarch64" => "arm64",
        "x86_64" => "x86_64",
        _ => "arm64", // Default to arm64 for Apple Silicon
    };

    // Build Swift package with correct architecture
    let status = Command::new("swift")
        .args(["build", "-c", "release", "--arch", swift_arch])
        .current_dir(&swift_dir)
        .status()
        .expect("Failed to build Swift package");

    if !status.success() {
        panic!("Swift build failed");
    }

    // Find the built library - check both possible locations
    let swift_build_dir = swift_dir.join(".build/release");
    let swift_build_dir_arch = swift_dir.join(format!(".build/{}-apple-macosx/release", swift_arch));
    
    // Use whichever exists
    let lib_dir = if swift_build_dir.join("libSCKBridge.a").exists() {
        swift_build_dir
    } else if swift_build_dir_arch.join("libSCKBridge.a").exists() {
        swift_build_dir_arch
    } else {
        panic!("Could not find libSCKBridge.a");
    };

    // Link the Swift library
    println!("cargo:rustc-link-search=native={}", lib_dir.display());
    println!("cargo:rustc-link-lib=static=SCKBridge");

    // Link required macOS frameworks
    println!("cargo:rustc-link-lib=framework=ScreenCaptureKit");
    println!("cargo:rustc-link-lib=framework=CoreGraphics");
    println!("cargo:rustc-link-lib=framework=CoreMedia");
    println!("cargo:rustc-link-lib=framework=CoreVideo");
    println!("cargo:rustc-link-lib=framework=Foundation");
    println!("cargo:rustc-link-lib=framework=AppKit");

    // Find Swift toolchain
    let xcode_path = String::from_utf8(
        Command::new("xcode-select")
            .arg("-p")
            .output()
            .expect("Failed to get Xcode path")
            .stdout,
    )
    .expect("Invalid UTF-8")
    .trim()
    .to_string();

    // Try multiple possible Swift library paths
    let possible_swift_paths = [
        format!("{}/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx", xcode_path),
        format!("{}/usr/lib/swift/macosx", xcode_path),
        "/usr/lib/swift".to_string(),
    ];

    for path in &possible_swift_paths {
        let path = PathBuf::from(path);
        if path.exists() {
            println!("cargo:rustc-link-search=native={}", path.display());
        }
    }

    // Link Swift runtime
    // On newer macOS, Swift runtime is part of the OS
    println!("cargo:rustc-link-lib=dylib=swiftCore");
}
