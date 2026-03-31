#import "Basic";
#import "Math";
#import "Input";

#load "renderer.jai";

main :: () {
    print("Initializing renderer...\n");
    
    renderer := init(800, 600, "OpenGL Renderer Test");
    if !renderer {
        print("Failed to create renderer!\n");
        return;
    }
    
    print("Loading font...\n");
    if !load_font(renderer, "assets/fonts/Nova_Square/NovaSquare-Regular.ttf") {
        print("Failed to load font!\n");
    }
    
    print("Entering main loop...\n");
    
    running := true;
    while running {
        reset_temporary_storage();
        update_window_events();
        
        for event : events_this_frame {
            if event.type == .QUIT {
                running = false;
            }
        }
        
        begin_frame(renderer);
        
        draw_rect(renderer, 350, 250, 450, 350, .{1, 0, 0, 1});
        
        draw_circle(renderer, 400, 300, 50, .{0, 1, 0, 1});
        
        immediate_triangle(
            renderer,
            200, 250,
            300, 250,
            250, 350,
            .{0, 0, 1, 1},
            .{0, 0.5, 1, 1},
            .{0, 1, 1, 1}
        );
        
        end_frame(renderer);
    }
    
    shutdown(renderer);
    print("Done!\n");
}
