//
//  OnboardingAnimations.swift
//  Wing
//
//  Created on 2026-02-20.
//

import SwiftUI

// MARK: - Slide 1 Animation: Wing Logo 三笔画绘制
struct WingLogoAnimationView: View {
    @State private var topProgress: CGFloat = 0.0
    @State private var middleProgress: CGFloat = 0.0
    @State private var bottomProgress: CGFloat = 0.0
    
    // 组合从 Figma 导出的高精度 SVG 路径 (合并了主笔画和细小墨迹)
    let topSVG = "M620.023 12.789C620.387 11.131 622.459 7.53099 624.626 4.78899C629.049 -0.806007 629.828 -1.27 628.954 2.21C628.488 4.067 628.823 4.76499 630.421 5.27299C632.115 5.80999 632.412 6.55499 632.052 9.36699C631.74 11.8 632.005 12.804 632.959 12.804C636.108 12.804 635.03 18.715 629.61 31.17C627.787 35.357 623.52 47.479 623.52 48.469C623.52 49.943 625.755 48.16 627.553 45.251C631.428 38.98 630.787 42.332 626.27 51.956C623.857 57.097 621.023 63.706 619.972 66.642C618.921 69.577 616.59 73.699 614.791 75.801C612.992 77.902 611.524 80 611.529 80.463C611.534 80.926 610.071 82.529 608.279 84.027C606.487 85.525 605.583 86.762 606.27 86.777C606.958 86.792 607.52 86.354 607.52 85.804C607.52 85.254 608.158 84.804 608.937 84.804C609.716 84.804 610.555 84.242 610.8 83.554C611.045 82.867 611.525 82.558 611.865 82.869C612.5 83.45 604.151 92.37 596.704 99.066C594.403 101.135 592.52 103.474 592.52 104.263C592.52 105.803 588.337 114.09 586.272 116.641C585.295 117.848 585.292 118.025 586.259 117.444C587.1 116.939 587.306 117.198 586.902 118.252C586.574 119.106 585.734 119.804 585.034 119.804C584.335 119.804 583.237 121.042 582.594 122.554C581.021 126.258 579.024 128.484 572.52 133.79C567.37 137.99 564.795 140.835 565.401 141.657C565.545 141.852 564.34 142.977 562.724 144.157C556.905 148.409 546.657 156.892 546.342 157.716C546.165 158.179 542.87 160.714 539.02 163.349C526.958 171.603 523.509 175.736 532.415 171.263C537.887 168.515 540.52 168.149 540.52 170.137C540.52 171.789 534.335 176.838 528.933 179.593C526.707 180.729 524.299 182.366 523.581 183.231C522.863 184.096 521.708 184.804 521.014 184.804C520.32 184.804 516.795 186.829 513.18 189.304C509.566 191.779 506.201 193.804 505.704 193.804C505.206 193.804 503.135 194.933 501.101 196.313C499.067 197.694 494.081 200.614 490.02 202.804C485.959 204.994 480.973 207.914 478.939 209.295C476.905 210.675 474.741 211.806 474.13 211.809C473.52 211.812 469.872 213.429 466.025 215.403C462.178 217.377 458.128 219.096 457.025 219.223C455.922 219.349 453.517 220.24 451.68 221.201C449.843 222.162 447.688 222.699 446.892 222.393C446.096 222.088 445.2 222.474 444.902 223.251C444.604 224.028 443.158 225.114 441.69 225.663C427.858 230.84 424.996 231.804 423.457 231.804C422.483 231.804 421.525 232.29 421.327 232.884C420.682 234.818 401.012 240.804 395.3 240.804C393.583 240.804 391.467 241.412 390.599 242.154C387.389 244.9 362.852 251.529 359.98 250.427C359.177 250.119 358.52 250.358 358.52 250.958C358.52 251.678 358.009 251.625 357.02 250.804C356.173 250.101 355.52 249.997 355.52 250.565C355.52 252.492 351.856 252.571 350.668 250.669C349.126 248.201 345.889 248.285 345.229 250.811C344.9 252.066 343.546 253.049 341.612 253.436C339.911 253.776 338.52 254.387 338.52 254.793C338.52 255.659 330.158 258.995 328.886 258.638C328.41 258.504 326.341 258.968 324.29 259.67C322.238 260.372 320.105 260.666 319.551 260.323C318.996 259.98 316.985 260.439 315.081 261.342C313.178 262.245 311.231 262.743 310.754 262.449C309.582 261.724 303.032 264.046 300.813 265.973C299.827 266.829 297.61 267.794 295.887 268.118C294.163 268.442 291.509 269.02 289.988 269.402C288.028 269.893 287.428 269.762 287.93 268.95C288.319 268.32 288.161 267.804 287.579 267.804C286.997 267.804 286.52 268.421 286.52 269.174C286.52 269.966 284.516 271.073 281.77 271.797C279.157 272.486 270.945 275.088 263.52 277.58C250.095 282.084 247.042 282.981 226.02 288.599C198.208 296.031 181.129 301.727 167.02 308.276C148.419 316.91 138.159 322.207 131.064 326.839C126.916 329.547 121.753 332.665 119.591 333.768C115.747 335.729 104.629 343.146 99.3884 347.245C97.9404 348.378 95.2834 350.429 93.4834 351.804C75.7064 365.382 51.8124 390.526 39.3164 408.804C32.3454 419.002 20.5204 438.077 20.5204 439.127C20.5204 440.28 13.8014 450.267 11.8904 451.955C9.64942 453.932 3.18342 455.832 1.73542 454.937C-1.45858 452.963 -0.247574 442.446 5.40043 423.094C7.99243 414.213 19.7984 384.906 23.0134 379.369C24.3114 377.133 26.1494 373.279 27.0964 370.804C28.0444 368.329 31.1644 362.704 34.0314 358.304C36.8984 353.904 40.8484 347.604 42.8084 344.304C48.7014 334.383 69.7454 309.031 78.7734 300.977C81.6534 298.407 85.2374 295.032 86.7374 293.478C88.2374 291.924 89.8454 290.887 90.3094 291.173C90.7734 291.46 91.9414 290.362 92.9034 288.733C93.8654 287.104 97.6604 283.537 101.336 280.807C105.012 278.078 109.37 274.533 111.02 272.93C112.67 271.327 116.045 268.73 118.52 267.16C120.995 265.589 123.784 263.629 124.719 262.804C125.653 261.979 129.478 259.729 133.219 257.804C136.959 255.879 140.245 254.057 140.52 253.756C142.538 251.545 180.998 231.866 189.02 228.941C195.801 226.468 196.446 226.198 205.753 221.942C209.457 220.248 215.082 218.004 218.253 216.954C221.425 215.904 225.595 214.351 227.52 213.502C229.445 212.653 234.395 210.952 238.52 209.723C242.645 208.494 246.47 207.164 247.02 206.768C247.57 206.373 251.17 205.279 255.02 204.338C266.212 201.601 274.248 198.806 276.886 196.731C278.233 195.671 280.058 194.804 280.941 194.804C281.825 194.804 283.329 194.37 284.284 193.84C286.934 192.37 311.939 184.27 321.52 181.779C326.195 180.563 331.595 178.967 333.52 178.232C335.445 177.496 348.72 173.082 363.02 168.422C394.546 158.148 394.312 158.227 403.02 154.788C406.87 153.268 413.62 150.805 418.02 149.315C422.42 147.826 429.27 145.077 433.242 143.206C437.213 141.335 440.655 139.804 440.889 139.804C441.444 139.804 464.469 129.103 466.843 127.741C467.846 127.166 470.546 125.739 472.843 124.571C476.178 122.875 490.033 115.074 501.735 108.304C509.499 103.812 524.464 94.528 531.946 89.56C536.938 86.246 544.62 81.283 549.02 78.531C553.42 75.779 560.495 70.89 564.743 67.666C568.991 64.442 572.742 61.804 573.08 61.804C573.417 61.804 576.51 58.992 579.952 55.554C583.395 52.117 591.21 44.579 597.32 38.804C603.43 33.029 610.527 25.492 613.092 22.054C615.656 18.617 618.116 15.804 618.558 15.804C619 15.804 619.659 14.447 620.023 12.789Z M550.242 162.038C550.691 162.184 552.147 161.292 553.478 160.054C556.601 157.15 556.953 157.214 554.92 160.316C554.015 161.697 552.105 163.121 550.675 163.48C549.246 163.839 546.652 165.642 544.912 167.487C542.464 170.083 541.618 170.503 541.174 169.344C540.791 168.347 542.076 166.83 545.012 164.809C547.44 163.139 549.793 161.892 550.242 162.038Z"
    let middleSVG = "M570.503 267.648C572.978 264.794 576.768 260.495 578.926 258.096C581.932 254.752 583.452 253.803 585.426 254.032C587.146 254.232 587.959 254.903 587.87 256.05C587.777 257.237 588.394 257.7 589.87 257.55C591.823 257.35 592.009 257.827 592.074 263.214C592.129 267.816 592.564 269.405 594.074 270.512C596.314 272.155 596.137 274.643 593.436 279.451C592.39 281.313 591.432 284.186 591.306 285.834C591.18 287.483 590.798 288.832 590.457 288.832C590.116 288.832 589.832 289.395 589.827 290.082C589.813 291.977 582.674 306.985 580.805 309.051C578.928 311.125 573.365 319.857 571.031 324.392C568.147 329.995 552.695 344.517 548.581 345.49C547.163 345.826 545.328 346.622 544.503 347.259C543.678 347.897 541.766 349.037 540.253 349.794C538.74 350.551 537.503 351.523 537.503 351.955C537.503 352.387 534.803 353.979 531.503 355.494C528.203 357.009 525.503 358.557 525.503 358.935C525.503 359.954 515.477 365.011 512.897 365.294C511.673 365.429 508.435 367.18 505.703 369.185C502.971 371.191 500.222 372.832 499.595 372.832C498.968 372.832 496.204 374.38 493.452 376.273C490.701 378.166 487.562 379.996 486.477 380.34C484.444 380.985 483.723 382.832 485.503 382.832C486.053 382.832 486.503 383.357 486.503 383.999C486.503 384.64 486.262 384.925 485.968 384.631C485.674 384.337 481.062 386.529 475.718 389.502C457.18 399.817 451.972 401.902 441.003 403.401C439.903 403.551 434.564 404.405 429.139 405.298C423.714 406.192 418.764 406.738 418.139 406.512C417.514 406.287 416.292 406.466 415.424 406.911C413.775 407.755 408.831 407.9 381.503 407.904C372.428 407.906 363.428 408.247 361.503 408.663C359.297 409.14 356.599 408.937 354.206 408.115C351.258 407.101 348.8 407.048 343.206 407.878C329.295 409.94 327.725 410.021 325.439 408.798C323.597 407.812 322.955 407.845 322.082 408.971C321.431 409.811 318.824 410.437 315.503 410.549C312.478 410.652 302.666 411.017 293.698 411.361C282.294 411.798 276.988 411.65 276.046 410.867C275.045 410.037 274.595 410.056 274.3 410.94C274.01 411.81 267.294 412.201 249.453 412.388C236.005 412.529 224.328 412.899 223.503 413.21C222.678 413.522 217.728 414.211 212.503 414.742C176.944 418.356 167.358 420.083 145.003 426.904C127.59 432.218 121.191 434.737 111.978 439.906C107.042 442.676 99.4032 446.77 95.0032 449.004C90.6032 451.238 83.0042 455.713 78.1162 458.949C73.2292 462.185 68.7292 464.84 68.1162 464.849C67.5042 464.859 65.8782 466.052 64.5032 467.501C60.8062 471.398 52.7272 477.136 46.6792 480.161C42.5382 482.232 40.9262 482.594 39.4202 481.788C36.9382 480.459 37.4582 478.199 42.9922 466.264C48.1612 455.115 55.8202 443.649 61.6482 438.332C64.0592 436.132 68.9662 431.632 72.5522 428.332C76.1372 425.032 85.5802 418.013 93.5372 412.735C130.979 387.894 133.498 386.442 154.018 377.869C159.51 375.575 164.903 373.31 166.003 372.836C171.049 370.663 193.841 364.505 202.615 362.944C205.578 362.417 211.828 361.263 216.503 360.379C221.178 359.495 226.578 358.538 228.503 358.251C232.548 357.649 232.877 357.593 245.503 355.369C250.728 354.449 257.928 353.316 261.503 352.852C271.857 351.507 282.874 349.826 284.503 349.342C285.328 349.097 293.653 348.192 303.003 347.33C312.353 346.469 322.478 345.341 325.503 344.823C328.528 344.305 333.759 343.706 337.127 343.493C340.495 343.28 343.782 342.778 344.43 342.377C345.079 341.976 352.898 341.473 361.806 341.259C370.714 341.045 382.356 340.284 387.677 339.569C392.998 338.854 397.15 338.594 396.905 338.99C396.269 340.02 400.881 339.604 401.601 338.566C401.931 338.092 405.306 337.216 409.101 336.62C418.256 335.181 430.386 332.485 439.003 329.976C442.853 328.854 450.603 326.604 456.225 324.975C461.847 323.346 472.197 319.744 479.225 316.971C486.253 314.197 496.702 310.23 502.445 308.155C508.187 306.08 514.262 303.453 515.945 302.317C517.627 301.181 521.703 299.16 525.003 297.826C530.229 295.714 538.09 291.665 546.468 286.772C553.215 282.831 566.509 272.254 570.503 267.648Z"
    let bottomSVG = "M472.165 481.868C472.349 481.34 477.45 479.124 483.5 476.945C495.887 472.482 498.616 471.95 495.423 474.62C494.281 475.575 493.507 476.838 493.703 477.426C493.899 478.014 490.451 481.942 486.041 486.156C478.061 493.779 477.233 495.042 482 492.317C486.094 489.977 486.378 490.609 482.836 494.176C481.001 496.023 478.137 499.06 476.471 500.926C474.804 502.791 470.304 506.89 466.471 510.034C456.618 518.114 446.457 527.812 446.74 528.865C446.872 529.356 446.085 530.237 444.99 530.822C443.637 531.546 443 531.556 443 530.852C443 530.283 442.502 529.817 441.893 529.817C441.284 529.817 441.04 530.478 441.35 531.286C441.706 532.214 440.824 533.399 438.957 534.502C437.331 535.462 436 536.628 436 537.092C436 537.555 435.607 537.692 435.126 537.395C434.645 537.098 432.958 537.984 431.376 539.364C426.172 543.905 421.027 547.178 420.274 546.425C419.971 546.121 418.4 546.985 416.784 548.345C415.169 549.705 413.42 550.817 412.899 550.817C412.377 550.817 411.515 551.962 410.983 553.363C410.45 554.763 409.449 555.8 408.757 555.668C408.066 555.536 405.387 556.415 402.805 557.622C400.223 558.829 397.437 559.817 396.614 559.817C395.791 559.817 394.808 560.319 394.429 560.932C394.011 561.608 392.024 561.854 389.388 561.557C386.414 561.222 384.676 561.502 383.896 562.442C383.269 563.198 382.173 563.817 381.461 563.817C380.749 563.817 380.007 564.295 379.812 564.88C379.372 566.201 376.954 566.496 359.817 567.314C348.977 567.831 344.857 567.64 339.986 566.392C336.605 565.526 330.792 564.817 327.068 564.817C323.345 564.817 318.994 564.416 317.399 563.925C315.805 563.434 311.8 562.49 308.5 561.826C296.041 559.32 274.329 553.595 270 551.674C260.301 547.372 250.104 543.837 241.5 541.796C233.429 539.881 226.635 537.604 216 533.251C214.075 532.463 207.55 530.291 201.5 528.423C195.45 526.556 186.45 523.641 181.5 521.945C176.55 520.249 168.225 517.937 163 516.807C157.775 515.676 150.699 514.089 147.275 513.279C139.014 511.326 123.185 509.636 114.5 509.78C108.021 509.888 102.009 511.074 86.5 515.305C80.281 517.001 60 518.207 60 516.881C60 516.466 60.9 515.312 62 514.317C63.1 513.322 64 511.967 64 511.307C64 509.171 74.312 500.292 81.378 496.345C95.823 488.274 116.008 482.345 139.179 479.367C162.062 476.426 185.453 477.361 215 482.398C235.753 485.936 238.91 486.595 269.68 493.82C288.171 498.162 295.394 499.422 324 503.295C343.914 505.992 373.241 506.776 380.007 504.793C381.928 504.23 386.875 503.305 391 502.739C400.619 501.417 412.376 499.204 422.5 496.809C426.9 495.768 433.65 494.206 437.5 493.337C441.35 492.468 445.85 491.128 447.5 490.361C457.288 485.807 469.795 481.572 471.091 482.373C471.497 482.624 471.98 482.397 472.165 481.868Z M436.25 540.945C434.664 542.188 434.629 542.153 435.872 540.567C436.627 539.605 437.415 538.817 437.622 538.817C438.445 538.817 437.916 539.638 436.25 540.945Z"
    
    var body: some View {
        ZStack {
            // 最上方笔画
            SVGPathShape(svgString: topSVG, originalViewBox: CGSize(width: 635, height: 568))
                .fill(Color.primary)
                .mask(SweepMask(progress: topProgress))
            
            // 中间笔画
            SVGPathShape(svgString: middleSVG, originalViewBox: CGSize(width: 635, height: 568))
                .fill(Color.primary)
                .mask(SweepMask(progress: middleProgress))
            
            // 最下方笔画
            SVGPathShape(svgString: bottomSVG, originalViewBox: CGSize(width: 635, height: 568))
                .fill(Color.primary)
                .mask(SweepMask(progress: bottomProgress))
        }
        .frame(width: 300, height: 300)
        .scaleEffect(0.6)
        .onAppear {
            let topDuration: Double = 1.2
            let middleDuration: Double = 0.8
            let bottomDuration: Double = 0.5
            let overlap: Double = 0.2
            
            withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: topDuration).delay(0.2)) {
                topProgress = 1.0
            }
            withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: middleDuration).delay(0.2 + topDuration - overlap)) {
                middleProgress = 1.0
            }
            withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: bottomDuration).delay(0.2 + topDuration + middleDuration - overlap * 2)) {
                bottomProgress = 1.0
            }
        }
    }
}

// MARK: - 从左向右展开的动画遮罩
struct SweepMask: View {
    var progress: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // 起点设在左下角（汇聚点附近）
                path.move(to: CGPoint(x: 0, y: geometry.size.height))
                // 向右上角挥动
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
            }
            .trim(from: 0, to: progress)
            // 使用超大线宽确保遮罩能完全覆盖整个笔触
            .stroke(Color.black, style: StrokeStyle(lineWidth: geometry.size.width * 1.5, lineCap: .butt))
        }
    }
}

// MARK: - 原生 SVG 路径解析引擎
struct SVGPathShape: Shape {
    let svgString: String
    let originalViewBox: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // 使用正则提取所有 M, C, Z 指令及其附带的数值
        let commandPattern = "([MCZ])([^MCZ]*)"
        let numberPattern = "-?\\d+(\\.\\d+)?"
        
        guard let commandRegex = try? NSRegularExpression(pattern: commandPattern),
              let numberRegex = try? NSRegularExpression(pattern: numberPattern) else {
            return path
        }
        
        let nsString = svgString as NSString
        let matches = commandRegex.matches(in: svgString, range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            let command = nsString.substring(with: match.range(at: 1))
            let argsString = nsString.substring(with: match.range(at: 2))
            
            let numMatches = numberRegex.matches(in: argsString, range: NSRange(location: 0, length: (argsString as NSString).length))
            let nums = numMatches.compactMap { Double((argsString as NSString).substring(with: $0.range)) }
            
            if command == "M" && nums.count >= 2 {
                path.move(to: CGPoint(x: nums[0], y: nums[1]))
            } else if command == "C" && nums.count >= 6 {
                for i in stride(from: 0, to: nums.count - 5, by: 6) {
                    path.addCurve(
                        to: CGPoint(x: nums[i+4], y: nums[i+5]),
                        control1: CGPoint(x: nums[i], y: nums[i+1]),
                        control2: CGPoint(x: nums[i+2], y: nums[i+3])
                    )
                }
            } else if command == "Z" {
                path.closeSubpath()
            }
        }
        
        // 将原始 ViewBox 的坐标按比例缩放到当前 SwiftUI 视图的 frame 中
        let scaleX = rect.width / originalViewBox.width
        let scaleY = rect.height / originalViewBox.height
        let scale = min(scaleX, scaleY)
        
        let offsetX = (rect.width - originalViewBox.width * scale) / 2
        let offsetY = (rect.height - originalViewBox.height * scale) / 2
        
        let transform = CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: offsetX, y: offsetY))
        
        return path.applying(transform)
    }
}

// MARK: - 预览
struct WingLogoAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        WingLogoAnimationView()
    }
}

// MARK: - Slide 2 Animation: 归拢合成 (Chat Bubbles to Journal)
struct SynthesisAnimationView: View {
    @State private var animateBubbles = false
    @State private var pressRecord = false
    @State private var recordProgress: CGFloat = 0.0
    @State private var particleProgress: CGFloat = 0.0
    @State private var pulseTab = false
    
    var body: some View {
        ZStack { // 外层包裹，用于放置全局粒子
            VStack(spacing: 24) {
                // 上方：方形白色画布区域
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(uiColor: .systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
                    
                    // 模拟的聊天气泡
                    VStack(spacing: 14) {
                        ChatBubbleShape(text: "今天看了很棒的晚霞")
                            .offset(y: animateBubbles ? 0 : 20)
                            .opacity(animateBubbles ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(0.2), value: animateBubbles)
                        
                        ChatBubbleShape(text: "不过下班回家的路上好堵...")
                            .offset(y: animateBubbles ? 0 : 20)
                            .opacity(animateBubbles ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(0.4), value: animateBubbles)
                        
                        ChatBubbleShape(text: "又吃了一顿减脂餐！")
                            .offset(y: animateBubbles ? 0 : 20)
                            .opacity(animateBubbles ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(0.6), value: animateBubbles)
                    }
                    .padding(.horizontal, 20)
                }
                .aspectRatio(1.0, contentMode: .fit) // 强制为正方形
                
                // 下方：分离的图标栏区域，占据左右两侧
                HStack {
                    // 左侧：日记 Tab
                    Image(systemName: "book.pages.fill")
                        .foregroundColor(pulseTab ? .accentColor : .secondary)
                        .font(.system(size: 28)) // 稍微放大一点增加质感
                        .scaleEffect(pulseTab ? 1.3 : 1.0)
                        // 用于辅助粒子找准终点位置
                        .padding(.leading, 12)
                    
                    Spacer()
                    
                    // 右侧：+号记录 Tab
                    ZStack {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 3)
                        
                        Circle()
                            .trim(from: 0, to: recordProgress)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 24))
                            .scaleEffect(pressRecord ? 0.9 : 1.0)
                    }
                    .frame(width: 48, height: 48)
                    .padding(.trailing, 12)
                }
                .padding(.horizontal, 16)
            }
            
            // 粒子效果覆盖在最顶层，不会被子节点裁剪
            GeometryReader { geo in
                ParticlePathView(progress: particleProgress, canvasSize: geo.size)
            }
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 32) // 控制整体宽度
        .onAppear {
            startAnimationCycle()
        }
    }
    
    private func startAnimationCycle() {
        animateBubbles = false
        pressRecord = false
        recordProgress = 0.0
        particleProgress = 0.0
        pulseTab = false
        
        // 阶段 1：气泡出现
        withAnimation { animateBubbles = true }
        
        // 阶段 2：长按记录
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) { pressRecord = true }
            withAnimation(.linear(duration: 1.0)) { recordProgress = 1.0 }
        }
        
        // 阶段 3：粒子飞向日记
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.easeInOut(duration: 0.2)) {
                pressRecord = false
                recordProgress = 0.0
            }
            withAnimation(.easeInOut(duration: 0.8)) { animateBubbles = false }
            withAnimation(.linear(duration: 0.8)) { particleProgress = 1.0 }
        }
        
        // 阶段 4：日记 Icon 脉冲跳动多次
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            particleProgress = 0.0
            // 跳动 3 次
            for i in 0..<3 {
                let delay = Double(i) * 0.35
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pulseTab = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pulseTab = false }
                    }
                }
            }
        }
        
        // 阶段 5：重置循环
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            startAnimationCycle()
        }
    }
}

struct ChatBubbleShape: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            // 可以带有一点微光或边界感提升精致度
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// 粒子路径 — 基于全局空间规划坐标
struct ParticlePathView: View, Animatable {
    var progress: CGFloat
    var canvasSize: CGSize
    
    // 关键修正：将 progress 暴露为可动画属性
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    var body: some View {
        Canvas { context, size in
            guard progress > 0 && progress <= 1 else { return }
            
            let width = size.width
            // 正方形画布的边长等于外层的宽度
            let canvasBoxHeight = width
            
            // 三个气泡的最初 Y 坐标偏移（分散在画布中上部区域）
            let bubbleYPositions: [CGFloat] = [
                canvasBoxHeight * 0.3,
                canvasBoxHeight * 0.5,
                canvasBoxHeight * 0.7
            ]
            
            // 终点：x是在左侧日记按钮区域（大概为 36），y 是画布高度 + HStack 的顶端边距 24 + HStack 中间位置大约 24
            let end = CGPoint(x: 36, y: canvasBoxHeight + 48)
            
            for (index, bubbleY) in bubbleYPositions.enumerated() {
                // 修改此处让 localProgress 可以达到 1.0 并多停留极短时间，避免最后一刻立刻消失
                let localProgress = max(0, min(1.0, progress * 1.3 - CGFloat(index) * 0.15))
                if localProgress > 0 && localProgress <= 1 {
                    // 起点：气泡右侧边缘
                    let start = CGPoint(x: width - 40, y: bubbleY)
                    // 控制点往下方发散，增加抛物线张力
                    let control = CGPoint(x: width * 0.2, y: canvasBoxHeight * 0.9)
                    
                    let position = calculateBezierPoint(start: start, control: control, end: end, t: localProgress)
                    
                    // 核心蓝点
                    context.fill(
                        Path(ellipseIn: CGRect(x: position.x - 4, y: position.y - 4, width: 8, height: 8)),
                        with: .color(.accentColor)
                    )
                    // 光晕
                    context.fill(
                        Path(ellipseIn: CGRect(x: position.x - 10, y: position.y - 10, width: 20, height: 20)),
                        with: .color(.accentColor.opacity(0.3))
                    )
                    
                    // 尾迹
                    if localProgress > 0.1 {
                        let trail = calculateBezierPoint(start: start, control: control, end: end, t: localProgress - 0.08)
                        context.fill(
                            Path(ellipseIn: CGRect(x: trail.x - 2.5, y: trail.y - 2.5, width: 5, height: 5)),
                            with: .color(.accentColor.opacity(0.5))
                        )
                    }
                }
            }
        }

    }
    
    private func calculateBezierPoint(start: CGPoint, control: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let x = pow(1-t, 2) * start.x + 2 * (1-t) * t * control.x + pow(t, 2) * end.x
        let y = pow(1-t, 2) * start.y + 2 * (1-t) * t * control.y + pow(t, 2) * end.y
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Slide 3 Animation: 记忆生长
struct MemoryGrowthAnimationView: View {
    @State private var showCard1 = false
    @State private var showCard2 = false
    @State private var showCard3 = false
    @State private var showCard4 = false
    @State private var showCard5 = false
    @State private var pulseBook = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // 圆角白底投影卡片
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
                
                // 中心日记本 Icon
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "book.pages.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 28))
                            .scaleEffect(pulseBook ? 1.08 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseBook)
                    )
                
                // 记忆胶囊
                Group {
                    MemoryPillView(text: "25岁")
                        .offset(x: -70, y: -90)
                        .opacity(showCard1 ? 1 : 0)
                        .scaleEffect(showCard1 ? 1 : 0.8)
                    
                    MemoryPillView(text: "养了只猫叫奈奈")
                        .offset(x: 50, y: -110)
                        .opacity(showCard2 ? 1 : 0)
                        .scaleEffect(showCard2 ? 1 : 0.8)
                    
                    MemoryPillView(text: "职场白领")
                        .offset(x: 80, y: -20)
                        .opacity(showCard3 ? 1 : 0)
                        .scaleEffect(showCard3 ? 1 : 0.8)
                    
                    MemoryPillView(text: "喜欢拉面")
                        .offset(x: -70, y: 30)
                        .opacity(showCard4 ? 1 : 0)
                        .scaleEffect(showCard4 ? 1 : 0.8)
                    
                    MemoryPillView(text: "看过的电影：好日子")
                        .offset(x: 20, y: 90)
                        .opacity(showCard5 ? 1 : 0)
                        .scaleEffect(showCard5 ? 1 : 0.8)
                }
            }
            .aspectRatio(1.0, contentMode: .fit)
            
            // 底部占位符以对齐 Slide 2
            Color.clear.frame(height: 48)
        }
        .padding(.horizontal, 32) // 与 Slide 2 等宽
        .onAppear {
            pulseBook = true
            startAnimationCycle()
        }
    }
    
    /// 使用 DispatchQueue 逐个延迟触发，确保每个胶囊都有独立的弹簧动画
    private func startAnimationCycle() {
        // 依次弹出每个胶囊
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showCard1 = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showCard2 = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showCard3 = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showCard4 = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showCard5 = true }
        }
        
        // 全部消失后重新循环
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showCard1 = false
                showCard2 = false
                showCard3 = false
                showCard4 = false
                showCard5 = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                startAnimationCycle()
            }
        }
    }
}

struct MemoryPillView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 3)
    }
}
