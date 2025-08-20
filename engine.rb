require 'matrix'

Color = Struct.new(:r, :g, :b) do
    def +(target)
        Color.new(r + target.r, g + target.g, b + target.b)
    end
    def *(target)
        new_r = (r * target).to_i > 255 ? 255 : (r * target).to_i
        new_g = (g * target).to_i > 255 ? 255 : (g * target).to_i
        new_b = (b * target).to_i > 255 ? 255 : (b * target).to_i
        Color.new(new_r, new_g, new_b)
    end
end

def v3(x, y, z)
    return Vector[x.to_f, y.to_f, z.to_f]
end

class Draw3D

    def initialize(polygon, parameters)
        @polygon = polygon
        @cv_size_x = parameters[:cv_size_x]
        @cv_size_y = parameters[:cv_size_y]
        if parameters[:cam_index] == 0 then
            @cam_pos = parameters[:cam_0][:pos]
            @cam_angle = parameters[:cam_0][:angle]
        else
            @cam_pos = parameters[:cam_1][:pos]
            @cam_angle = parameters[:cam_1][:angle]
        end
        @z_near = 0.01
        @zoom = parameters[:zoom] * @cv_size_x / 640.0
        @light = v3(3000, 3000, -3000)

        if parameters[:cam_index] == 1 && parameters[:is_cam_0_object] then
            add_cam_object(parameters[:cam_0][:pos], parameters[:cam_0][:angle])
        end

        @output_file_name = parameters[:output_file_name]
    end

    # 座標軸オブジェクトの追加
    def add_cam_object(pos, angle)

        cam_color_list = { o: Color.new(255, 255, 255), x: Color.new(255, 0, 0), y: Color.new(0, 255, 0), z: Color.new(0, 0, 255) }

        cam_polygon = [
            {vertex: [v3(-2, 2, -2), v3(-2, -2, -2), v3(2, -2, -2), v3(2, 2, -2)], color: cam_color_list[:o]},
            {vertex: [v3(-2, 2, 2), v3(-2, -2, 2), v3(-2, -2, -2), v3(-2, 2, -2)], color: cam_color_list[:o]},
            {vertex: [v3(-2, -2, -2), v3(-2, -2, 2), v3(2, -2, 2), v3(2, -2, -2)], color: cam_color_list[:o]},

            {vertex: [v3(2, 2, -2), v3(2, -2, -2), v3(22, -2, -2), v3(22, 2, -2)], color: cam_color_list[:x]},
            {vertex: [v3(2, 2, 2), v3(2, -2, 2), v3(22, -2, 2), v3(22, 2, 2)], color: cam_color_list[:x], is_bc: true},
            {vertex: [v3(2, 2, 2), v3(2, 2, -2), v3(22, 2, -2), v3(22, 2, 2)], color: cam_color_list[:x]},
            {vertex: [v3(2, -2, 2), v3(2, -2, -2), v3(22, -2, -2), v3(22, -2, 2)], color: cam_color_list[:x], is_bc: true},
            {vertex: [v3(22, 2, -2), v3(22, -2, -2), v3(22, -2, 2), v3(22, 2, 2)], color: cam_color_list[:x]},

            {vertex: [v3(-2, 22, -2), v3(-2, 2, -2), v3(2, 2, -2), v3(2, 22, -2)], color: cam_color_list[:y]},
            {vertex: [v3(-2, 22, 2), v3(-2, 2, 2), v3(2, 2, 2), v3(2, 22, 2)], color: cam_color_list[:y], is_bc: true},
            {vertex: [v3(2, 22, -2), v3(2, 2, -2), v3(2, 2, 2), v3(2, 22, 2)], color: cam_color_list[:y]},
            {vertex: [v3(-2, 22, -2), v3(-2, 2, -2), v3(-2, 2, 2), v3(-2, 22, 2)], color: cam_color_list[:y], is_bc: true},
            {vertex: [v3(-2, 22, 2), v3(-2, 22, -2), v3(2, 22, -2), v3(2, 22, 2)], color: cam_color_list[:y]},

            {vertex: [v3(-2, 2, 22), v3(-2, 2, 2), v3(2, 2, 2), v3(2, 2, 22)], color: cam_color_list[:z]},
            {vertex: [v3(-2, 2, 22), v3(-2, 2, 2), v3(2, 2, 2), v3(2, 2, 22)], color: cam_color_list[:z], is_bc: true},
            {vertex: [v3(2, 2, 2), v3(2, -2, 2), v3(2, -2, 22), v3(2, 2, 22)], color: cam_color_list[:z]},
            {vertex: [v3(2, 2, 2), v3(2, -2, 2), v3(2, -2, 22), v3(2, 2, 22)], color: cam_color_list[:z], is_bc: true},
            {vertex: [v3(-2, 2, 22), v3(-2, -2, 22), v3(2, -2, 22), v3(2, 2, 22)], color: cam_color_list[:z], is_bc: true},
        ]

        cam_polygon.each_index do |i|
            cam_polygon[i][:vertex].each_index do |j|
                cam_polygon[i][:vertex][j] = angle * cam_polygon[i][:vertex][j] + pos
            end
        end
        @polygon += cam_polygon
    end

    # プロジェクション・スクリーン座標変換
    def view_2_scr_x(x) return x * @zoom + @cv_size_x / 2 end
    def view_2_scr_y(y) return -y * @zoom + @cv_size_y / 2 end

    def scr_2_view_x(x) return (x - @cv_size_x / 2).to_f / @zoom end
    def scr_2_view_y(y) return (- y + @cv_size_y / 2).to_f / @zoom end

    # クリッピング
    def shape_clip(vertex)
        vertex_view = []
        xmin = Float::INFINITY
        xmax = -Float::INFINITY
        ymin = Float::INFINITY
        ymax = -Float::INFINITY

        border_update = lambda do |x, y| 
            if x < xmin then xmin = x end
            if x > xmax then xmax = x end
            if y < ymin then ymin = y end
            if y > ymax then ymax = y end
        end

        vertex.each_index do |i|
            i_next = i + 1
            if i_next >= vertex.length then i_next = 0 end

            if vertex[i][2] >= @z_near then
                vx = vertex[i][0].to_f / vertex[i][2]
                vy = vertex[i][1].to_f / vertex[i][2]
                vertex_view.push(v3(vx, vy, 1))
                border_update.call(vx, vy)
            end
            if (vertex[i][2] >= @z_near) ^ (vertex[i_next][2] >= @z_near) then
                ratio = (@z_near - vertex[i][2]) / (vertex[i_next][2] - vertex[i][2])
                clip_x = vertex[i][0] + ratio * (vertex[i_next][0] - vertex[i][0])
                clip_y = vertex[i][1] + ratio * (vertex[i_next][1] - vertex[i][1])
                vx = clip_x / @z_near
                vy = clip_y / @z_near
                vertex_view.push(v3(vx, vy, 1))
                border_update.call(vx, vy)
            end
        end
        return vertex_view, xmin, xmax, ymin, ymax
    end

    # 凸多角形の内外判定
    def shape_judge(px, py, vertex)
        point = v3(px, py, 1)
        cross_pm = lambda do |i|
            i_next = i + 1
            if i_next >= vertex.length then i_next = 0 end
            return (point - vertex[i]).cross(vertex[i_next] - vertex[i])[2] > 0
        end
        c1 = cross_pm.call(0)
        (vertex.length - 1).times do |i|
            if cross_pm.call(i + 1) != c1 then
                return false
            end
        end
        return true
    end

    # 画像ファイルの出力
    def writeimage(img, name)
        File.open(name, "wb") do |f|
            f.puts("P6\n#{@cv_size_x} #{@cv_size_y}\n255")
            img.each do |a|
                a.each do |p| f.write(p.to_a.pack("ccc")) end
            end
        end
    end

    def draw

        # ビュー・プロジェクション座標の保存
        polygon_view_n = []
        polygon_view_d = []
        polygon_pj = []
        polygon_pj_color = []
        polygon_scr_border = []
        total_count = 0

        @polygon.each_index do |i|

            each_view = []
            is_exist_plus = false

            # ワールド・ビュー座標変換
            @polygon[i][:vertex].each_index do |j|

                view = @cam_angle.t * (@polygon[i][:vertex][j] - @cam_pos)
                is_exist_plus = is_exist_plus || view[2] >= @z_near
                each_view.push(view)

            end

            # 裏面判定
            each_n = -(each_view[1] - each_view[0]).cross(each_view[2] - each_view[0]).normalize
            if (@polygon[i][:is_bc] || (@polygon[i][:is_ds] && each_n.dot(each_view[0]) > 0)) then each_n *= -1 end

            if is_exist_plus && (each_n.dot(each_view[0]) < 0) then

                # z_nearのクリッピング
                pj, pj_xmin, pj_xmax, pj_ymin, pj_ymax = shape_clip(each_view)

                scr_xmin = view_2_scr_x(pj_xmin).to_i
                scr_xmax = view_2_scr_x(pj_xmax).to_i
                scr_ymin = view_2_scr_y(pj_ymax).to_i
                scr_ymax = view_2_scr_y(pj_ymin).to_i

                # xyの境界のクリッピング
                if 0 <= scr_xmax && scr_xmin <= @cv_size_x && 0 <= scr_ymax && scr_ymin <= @cv_size_y then

                    if scr_xmin < 0 then scr_xmin = 0 end
                    if scr_xmax > @cv_size_x then scr_xmax = @cv_size_x end
                    if scr_ymin < 0 then scr_ymin = 0 end
                    if scr_ymax > @cv_size_y then scr_ymax = @cv_size_y end

                    # ビュー・プロジェクション座標を記録する
                    polygon_pj.push(pj)
                    polygon_scr_border.push({xmin: scr_xmin, xmax: scr_xmax, ymin: scr_ymin, ymax: scr_ymax})
                    polygon_pj_color.push(@polygon[i][:color])
                    polygon_view_n.push(each_n)
                    polygon_view_d.push(-each_n.dot(each_view[0]))

                    total_count += (scr_xmax - scr_xmin) * (scr_ymax - scr_ymin)
                end
            end
        end

        # 画像の保存領域
        img = Array.new(@cv_size_y) do Array.new(@cv_size_x) do Color.new(0, 0, 0) end end
        grid_color = Array.new(@cv_size_y + 1) do Array.new(@cv_size_x + 1) do Color.new(134, 202, 249) end end  # 背景色
        grid_depth = Array.new(@cv_size_y + 1) do Array.new(@cv_size_x + 1) do Float::INFINITY end end

        count = 0

        polygon_pj.each_index do |i|

            # 深度を計算するための領域
            plain_const = -polygon_view_d[i]

            sy = polygon_scr_border[i][:ymin]
            py = scr_2_view_y(sy)

            sx_left = polygon_scr_border[i][:xmin]
            px_left = scr_2_view_x(sx_left)

            pdepth_left = (polygon_view_n[i][0] * px_left + polygon_view_n[i][1] * py + polygon_view_n[i][2]) / plain_const

            # フラットシェーディングによる隠の色の決定
            rate = polygon_view_n[i].dot(@light) / @light.norm
            if rate < 0 then rate = 0 end
            pcolor = polygon_pj_color[i] * (rate * 0.2 + 0.9)

            # 各ピクセルごとに処理する
            while true

                sy += 1
                if sy > polygon_scr_border[i][:ymax] then break end

                py -= 1 / @zoom
                pdepth_left -= polygon_view_n[i][1] / (@zoom * plain_const)
                pdepth = pdepth_left

                sx = sx_left
                px = px_left

                while true

                    sx += 1
                    if sx > polygon_scr_border[i][:xmax] then break end

                    px += 1 / @zoom
                    pdepth += polygon_view_n[i][0] / (@zoom * plain_const)
                    
                    # 凸多角形の内外判定
                    if shape_judge(px, py, polygon_pj[i]) then
                    
                        # 深度を比較する
                        if grid_depth[sy][sx] - 1 / pdepth > -1 then

                            grid_color[sy][sx] = pcolor
                            grid_depth[sy][sx] = 1 / pdepth

                        end
                    end

                    if (count % 1e+4 == 0) || (count == total_count - 1) then puts "#{count}/#{total_count - 1} passed" end
                    count += 1
                end
            end
        end

        # 色の平均をとる
        (@cv_size_y).times do |sy|

            (@cv_size_x).times do |sx|

                img[sy][sx] = (grid_color[sy][sx] + grid_color[sy][sx+1] + grid_color[sy+1][sx] + grid_color[sy+1][sx+1]) * 0.25

            end
        end

        writeimage(img, @output_file_name)
        return "success!!"
    end
end

# 直交座標による位置および回転行列の生成
def cam_rectangular(x, y, z, roll, pitch, yaw)

    roll *= Math::PI / 180
    pitch *= Math::PI / 180
    yaw *= Math::PI / 180

    pos = v3(x, y, z)

    rst = Matrix[[1, 0, 0], [0, Math.cos(roll), -Math.sin(roll)], [0, Math.sin(roll), Math.cos(roll)]]
    rst *= Matrix[[Math.cos(pitch), 0, Math.sin(pitch)], [0, 1, 0], [-Math.sin(pitch), 0, Math.cos(pitch)]]
    rst *= Matrix[[Math.cos(yaw), -Math.sin(yaw), 0], [Math.sin(yaw), Math.cos(yaw), 0], [0, 0, 1]]

    return {pos: pos, angle: rst}
end

# 極座標による位置および回転行列の生成
def cam_polar(cx, cy, cz, l, alpha, beta)

    alpha *= Math::PI / 180
    if beta > 90 then beta = 90 elsif beta < -90 then beta = -90 end
    beta *= Math::PI / 180

    rp = v3(l * Math.sin(alpha) * Math.cos(beta), l * Math.sin(beta), l * -Math.cos(alpha) * Math.cos(beta))
    pos = rp + v3(cx, cy, cz)

    ez = -rp.normalize
    if beta.abs == Math::PI / 2 then
        ex = v3(Math.cos(alpha), 0, Math.sin(alpha))
    else
        ex = v3(0, 1, 0).cross(ez)
    end
    ey = ez.cross(ex)
    rst = Matrix.columns([ex, ey, ez])

    return {pos: pos, angle: rst}
end
