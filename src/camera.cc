//
// Created by alexandre on 28/05/19.
//

#include "camera.hh"

Camera::Camera()
{
    pos = glm::vec3(0.0f, 0.0f,  25.0f);
    front = glm::vec3(0.0f, 0.0f, -1.0f);
    right = glm::vec3(1.0f, 0.0f, 0.0f);
    up = glm::vec3(0.0f, 1.0f,  0.0f);
    fov = 45.f;

    speed = 15.f;
    sensitivity = 0.03f;

    yaw = -90.f;
    pitch = 0.f;

    first_mouse_move = true;
}