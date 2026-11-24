#include "image_clipboard.h"

#include <gtk/gtk.h>

// Decodifica el PNG y lo deja en el portapapeles (GTK lo sirve en los
// formatos de imagen que pida la app que pega).
static gboolean copy_png(const uint8_t* data, size_t len) {
  g_autoptr(GdkPixbufLoader) loader = gdk_pixbuf_loader_new_with_type("png", NULL);
  if (loader == NULL) return FALSE;
  gboolean ok = gdk_pixbuf_loader_write(loader, data, len, NULL);
  ok = gdk_pixbuf_loader_close(loader, NULL) && ok;
  GdkPixbuf* pixbuf = ok ? gdk_pixbuf_loader_get_pixbuf(loader) : NULL;
  if (pixbuf == NULL) return FALSE;
  GtkClipboard* cb = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
  gtk_clipboard_set_image(cb, pixbuf);
  gtk_clipboard_store(cb);  // que siga ahí si se cierra la app (con gestor)
  return TRUE;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* call,
                           gpointer user_data) {
  g_autoptr(FlMethodResponse) response = NULL;
  FlValue* args = fl_method_call_get_args(call);
  if (g_strcmp0(fl_method_call_get_name(call), "copyImage") != 0) {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  } else if (args == NULL ||
             fl_value_get_type(args) != FL_VALUE_TYPE_UINT8_LIST) {
    response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("bad_args", "PNG bytes expected", NULL));
  } else {
    gboolean ok = copy_png(fl_value_get_uint8_list(args),
                           fl_value_get_length(args));
    g_autoptr(FlValue) result = fl_value_new_bool(ok);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  fl_method_call_respond(call, response, NULL);
}

void image_clipboard_register_with_registrar(FlPluginRegistrar* registrar) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  // El canal vive lo que la app: no se libera.
  FlMethodChannel* channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "pandive/clipboard",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, NULL,
                                            NULL);
}
