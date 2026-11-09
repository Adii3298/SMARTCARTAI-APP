import os
from PIL import Image, ImageDraw, ImageFont

def generate_app_icons():
    icons_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static", "icons")
    os.makedirs(icons_dir, exist_ok=True)

    sizes = [72, 96, 128, 144, 152, 192, 384, 512]

    for size in sizes:
        # Create gradient-style background
        img = Image.new("RGBA", (size, size), color=(16, 185, 129, 255))
        draw = ImageDraw.Draw(img)

        # Draw rounded inner tile
        padding = int(size * 0.08)
        draw.rounded_rectangle(
            [(padding, padding), (size - padding, size - padding)],
            radius=int(size * 0.22),
            fill=(5, 150, 105, 255),
            outline=(52, 211, 153, 255),
            width=max(2, int(size * 0.02))
        )

        # Draw shopping cart motif
        w = size
        cx, cy = w // 2, w // 2
        
        # Cart body
        cart_w = int(w * 0.44)
        cart_h = int(w * 0.28)
        draw.rectangle(
            [(cx - cart_w // 2, cy - cart_h // 2), (cx + cart_w // 2, cy + cart_h // 2)],
            fill=(255, 255, 255, 255)
        )
        # Cart handle
        draw.line(
            [(cx - cart_w // 2, cy - cart_h // 2), (cx - cart_w // 2 - int(w * 0.1), cy - cart_h // 2 - int(w * 0.1))],
            fill=(255, 255, 255, 255),
            width=max(3, int(w * 0.04))
        )
        # Cart wheels
        r = max(3, int(w * 0.05))
        draw.ellipse([(cx - int(cart_w * 0.3) - r, cy + cart_h // 2 + int(w * 0.06) - r),
                      (cx - int(cart_w * 0.3) + r, cy + cart_h // 2 + int(w * 0.06) + r)], fill=(255, 255, 255, 255))
        draw.ellipse([(cx + int(cart_w * 0.3) - r, cy + cart_h // 2 + int(w * 0.06) - r),
                      (cx + int(cart_w * 0.3) + r, cy + cart_h // 2 + int(w * 0.06) + r)], fill=(255, 255, 255, 255))

        # Save icon
        out_file = os.path.join(icons_dir, f"icon-{size}.png")
        img.save(out_file, "PNG")
        print(f"Generated icon: {out_file}")

if __name__ == "__main__":
    generate_app_icons()
