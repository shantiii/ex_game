-module(eg_frame).

%% Entry point
-export([start_link/0]).

%% wx_object callbacks
-export([init/1,
         code_change/3,
         handle_call/3,
         handle_cast/2,
         handle_event/2,
         handle_info/2,
         terminate/2
        ]).

-behaviour(wx_object).

-include_lib("wx/include/gl.hrl").
-include_lib("wx/include/glu.hrl").
-include_lib("wx/include/wx.hrl").
-define(WX_GL_SAMPLE_BUFFERS,17).  %% 1 for multisampling support (antialiasing)
-define(WX_GL_SAMPLES,18). %% 4 for 2x2 antialiasing supersampling on most graphics cards

%% API

start_link() ->
  wx:new(),
  Config = [{env, wx:get_env()}],
  Frame = wx_object:start_link({local, ?MODULE}, ?MODULE, Config, []),
  {ok, wx_object:get_pid(Frame)}.

%% wx Callbacks
% Initialization
init(Args) ->
  process_flag(trap_exit, true),
  WxEnv = proplists:get_value(env, Args),
  wx:set_env(WxEnv),
  Frame = wxFrame:new(wx:null(), -1, "ExGame", [{size, {300, 300}}]),
  GLCanvas = wxGLCanvas:new(Frame, canvas_opts()),
  wxGLCanvas:connect(GLCanvas, size),
  wxGLCanvas:connect(GLCanvas, paint),
  wxWindow:hide(Frame),
  wxWindow:reparent(GLCanvas, Frame),
  wxWindow:show(Frame),
  wxGLCanvas:setCurrent(GLCanvas),
  {VAO, ShaderProgram} = gl_init(),
  {Frame, #{frame=>Frame,
            counter=>0,
            shader_program=>ShaderProgram,
            vao=>VAO
           }}.

handle_call(Msg, _Sender, State) ->
  log({cast, Msg}),
  {noreply, State}.

handle_cast(Msg, State) ->
  log({cast, Msg}),
  {noreply, State}.

handle_event(#wx{obj=GLCanvas,
                 event=#wxSize{size={Width,Height}}}, State) ->
  resize(Width, Height),
  draw(State),
  wxGLCanvas:swapBuffers(GLCanvas),
  wxGLCanvas:setCurrent(GLCanvas),
  {noreply, State};
handle_event(#wx{obj=GLCanvas, event=#wxPaint{}}, 
             #{counter:=Counter} = State) ->
  {Time, _} = timer:tc(fun draw/1, [State]),
  %% draw(State),
  erlang:display({time, Time}),
  wxGLCanvas:swapBuffers(GLCanvas),
  case Counter rem 100 of
    0 -> erlang:display({counter, Counter});
    _ -> ok
  end,
  {noreply, State#{counter:=Counter+1}};
handle_event(Msg, State) ->
  log({event, Msg}),
  {noreply, State}.

handle_info(Msg, State) ->
  log({info, Msg}),
  {noreply, State}.

code_change(_Old, _New, State) ->
  log("code change"),
  State.

terminate(Reason, #{frame:=Frame}) ->
  log({terminate, Reason}),
  catch wxFrame:destroy(Frame),
  erlang:halt(),
  shutdown.

%% Internals

log(Message) ->
  io:format("~p~n",[Message]),
  ok.

attributes() ->
  [?WX_GL_RGBA,
   ?WX_GL_MIN_RED,8,?WX_GL_MIN_GREEN,8,?WX_GL_MIN_BLUE,8,
   ?WX_GL_DEPTH_SIZE, 24, ?WX_GL_STENCIL_SIZE, 8,
   ?WX_GL_DOUBLEBUFFER,
   ?WX_GL_SAMPLE_BUFFERS,1,
   ?WX_GL_SAMPLES, 4,
   0].

canvas_opts() ->
  Style = ?wxFULL_REPAINT_ON_RESIZE bor ?wxWANTS_CHARS,
  [{style, Style}, {attribList, attributes()}].

canvas_setup(Canvas) ->
  ok.

%% openGL functions

resize(Width, Height) ->
  gl:viewport(0, 0, Width, Height),
  gl:matrixMode(?GL_PROJECTION),
  gl:loadIdentity(),
  glu:perspective(45.0, Width / Height, 0.1, 100.0),
  gl:matrixMode(?GL_MODELVIEW),
  gl:loadIdentity().

draw(State) ->
  gl:clear(?GL_COLOR_BUFFER_BIT bor
           ?GL_DEPTH_BUFFER_BIT bor
           ?GL_STENCIL_BUFFER_BIT),
  gl:loadIdentity(),
  #{ shader_program := ShaderProgram, vao := VAO } = State,
  gl:useProgram(ShaderProgram),
  gl:bindVertexArray(VAO),
  gl:drawArrays(?GL_TRIANGLES, 0, 3),
  gl:bindVertexArray(0),
  ok.

gl_init() ->
  gl:shadeModel(?GL_SMOOTH),
  gl:clearColor(0.0, 0.0, 0.0, 0.0),
  gl:clearDepth(1.0),
  gl:enable(?GL_DEPTH_TEST),
  gl:depthFunc(?GL_LEQUAL),
  gl:hint(?GL_PERSPECTIVE_CORRECTION_HINT, ?GL_NICEST),
  ShaderProgram = init_shaders(),
  VAO = init_vertex_array(),
  {VAO, ShaderProgram}.

init_shaders() ->
  VertexShader = gl:createShader(?GL_VERTEX_SHADER),
  gl:shaderSource(VertexShader, vertex_shader_source()),
  gl:compileShader(VertexShader),
  FragmentShader = gl:createShader(?GL_FRAGMENT_SHADER),
  gl:shaderSource(FragmentShader, fragment_shader_source()),
  gl:compileShader(FragmentShader),
  ShaderProgram = gl:createProgram(),
  gl:attachShader(ShaderProgram, VertexShader),
  gl:attachShader(ShaderProgram, FragmentShader),
  gl:linkProgram(ShaderProgram),
  gl:deleteShader(VertexShader),
  gl:deleteShader(FragmentShader),
  ShaderProgram.

vertex_shader_source() ->
  "
  #version 330 core

  layout (location = 0) in vec3 position;

  void main()
  {
        gl_Position = vec4(position.x, position.y, position.z, 1.0);
  }
  ".

fragment_shader_source() ->
  "
  #version 330 core

  out vec4 color;

  void main()
  {
        color = vec4(0.5, 0.5, 0.2, 1.0);
  } 
  ".

init_vertex_array() ->
  Triangle = compile_vertices(triangle()),
  [VBO] = gl:genBuffers(1),
  [VAO] = gl:genVertexArrays(1),
  gl:bindVertexArray(VAO),
  gl:bindBuffer(?GL_ARRAY_BUFFER, VBO),
  gl:bufferData(?GL_ARRAY_BUFFER,
                byte_size(Triangle), Triangle,
                ?GL_STATIC_DRAW),
  gl:vertexAttribPointer(0, 3, ?GL_FLOAT, ?GL_FALSE, 3*4, 0),
  gl:enableVertexAttribArray(0),
  gl:bindVertexArray(0),
  VAO.

triangle() ->
  [{0, 0.5, -1.5},
   {-0.5, -0.5, -1.5},
   {0.5, -0.5, -1.5}].

compile_vertices(Vertices) ->
  lists:foldl(
    fun({X,Y,Z}, Bin) -> <<Bin/binary,
                           X:32/float-native,
                           Y:32/float-native,
                           Z:32/float-native>>
    end,
    <<>>,
    Vertices).
