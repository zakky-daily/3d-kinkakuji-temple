require "./modeling"

$parameters[:cv_size_x] = 640
$parameters[:cv_size_y] = 480

animation_length = 36

(animation_length * 10).times do |i|

    p "animation #{i + 1}/#{animation_length * 10}"

    $parameters[:cam_1] = cam_polar(0, 190, 0, 700, -i * 3, 30 - 20 * Math.cos(i * Math::PI / 45))
    $parameters[:output_file_name] = format("animation/img_%03d.ppm", i)
    Draw3D.new($model, $parameters).draw

end