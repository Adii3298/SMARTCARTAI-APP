import os
import random
from PIL import Image, ImageDraw, ImageFont

def create_sample_grocery_image(text_lines, output_path, title="My Grocery List"):
    width, height = 650, 850
    # Create yellowish / ruled notebook paper texture
    img = Image.new("RGB", (width, height), color=(254, 252, 240))
    draw = ImageDraw.Draw(img)

    # Draw pink left margin line
    draw.line([(85, 0), (85, height)], fill=(244, 160, 160), width=2)

    # Draw blue ruled notebook lines
    line_y = 120
    spacing = 52
    while line_y < height - 50:
        draw.line([(0, line_y), (width, line_y)], fill=(200, 220, 240), width=1)
        line_y += spacing

    # Title
    draw.text((105, 50), title, fill=(30, 41, 59))
    draw.line([(105, 95), (320, 95)], fill=(30, 41, 59), width=2)

    # Handwriting imitation colors (blue fountain pen or dark pencil ink)
    ink_color = (25, 45, 110)

    # Draw items with natural handwritten look and bullet dots
    current_y = 142
    for i, line in enumerate(text_lines):
        # Draw checkbox or bullet
        draw.rectangle([(60, current_y + 4), (74, current_y + 18)], outline=(120, 120, 120), width=1)
        
        # Slight jitter for realistic handwriting feel
        x_jitter = random.randint(-1, 2)
        y_jitter = random.randint(-2, 2)
        
        # Draw bold-ish handwritten text
        for dx in range(2):
            for dy in range(2):
                draw.text((105 + x_jitter + dx, current_y + y_jitter + dy), f"{i+1}.  {line}", fill=ink_color)

        current_y += spacing

    # Add a little footer note
    draw.text((105, height - 70), "* Urgent: buy from local kirana today", fill=(100, 116, 139))

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path, "JPEG", quality=90)
    print(f"Created sample image: {output_path}")

if __name__ == "__main__":
    base_dir = os.path.dirname(os.path.abspath(__file__))
    samples_dir = os.path.join(base_dir, "static", "samples")
    
    weekly = [
        "Aashirvaad Shudh Chakki Atta 5 kg",
        "Fortune Mustard Oil 1 Ltr",
        "Tata Sampann Toor Dal 1 kg",
        "Amul Taaza Milk 2 packets",
        "Tata Salt 1 kg",
        "Madhur Pure Sugar 2 kg",
        "Daawat Rozana Basmati Rice 2 kg",
        "Everest Haldi Powder 200 gm"
    ]
    create_sample_grocery_image(weekly, os.path.join(samples_dir, "sample_weekly_ration.jpg"), "Weekly Kirana Ration")

    breakfast = [
        "Amul Taaza Milk 1 packet",
        "Amul Butter Pasteurised 1 packet",
        "Tata Tea Gold 250 gm",
        "Maggi 2-Minute Noodles 4 packets",
        "Parle-G Glucose Biscuits 2 packets",
        "Madhur Pure Sugar 1 kg"
    ]
    create_sample_grocery_image(breakfast, os.path.join(samples_dir, "sample_breakfast.jpg"), "Daily Essentials List")
